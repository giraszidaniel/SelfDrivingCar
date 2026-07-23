import os
import socket
import threading
import webbrowser
import time
from flask import Flask, render_template_string, request, jsonify

app = Flask(__name__)

# Globális változók a kliens kapcsolat tárolására
c_client_socket = None
client_lock = threading.Lock()

# DINAMIKUS ÚTVONAL: Megkeressük a jelenlegi Python fájl pontos mappáját
script_dir = os.path.dirname(os.path.abspath(__file__))
html_fajl_utvonal = os.path.join(script_dir, "index.html")

# HTML tartalom beolvasása a fix útvonal alapján
try:
    with open(html_fajl_utvonal, "r", encoding="utf-8") as f:
        html_content = f.read()
except FileNotFoundError:
    html_content = f"<h3>Hiba: Az index.html fájl nem található a következő helyen: {html_fajl_utvonal}</h3>"


@app.route('/')
def home():
    return render_template_string(html_content)


@app.route('/kuld', methods=['POST'])
def fogad_uzenet():
    global c_client_socket
    adat = request.get_json()
    kliens_uzenet = adat.get('uzenet', 'Nincs uzenet')
    
    print(f"[WEB] Gombnyomás érkezett: {kliens_uzenet}")
    
    gomb_kod = "0"
    if "1" in kliens_uzenet:
        gomb_kod = "1"
    elif "2" in kliens_uzenet:
        gomb_kod = "2"

    with client_lock:
        if c_client_socket:
            try:
                c_client_socket.send(gomb_kod.encode())
                print(f"[SOCKET] -> Sikeresen elküldve a C kódnak: {gomb_kod}")
                statusz = f"Továbbítva a C kliensnek: {gomb_kod}"
            except socket.error:
                print("[SOCKET] Hiba a küldés során, a kapcsolat megszakadhatott.")
                c_client_socket = None
                statusz = "Hiba: A C kliens szétkapcsolt!"
        else:
            statusz = "A C kliens még nem csatlakozott a socketre!"
            print(f"[SOCKET] ⚠️ {statusz}")

    return jsonify({"status": statusz})


# Külön függvény a socket szervernek, ami egy háttérszálon fog futni
def socket_szerver_futatasa():
    global c_client_socket
    port = 2222
    
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('', port))
        s.listen(5)
        print(f"[SOCKET] Szerver elindult a {port}-es porton. Várakozás a C kliensre...")
    except socket.error as err:
        print(f"[SOCKET] Szerver indítási hiba: {err}")
        return

    while True:
        try:
            c, addr = s.accept()
            print(f"[SOCKET] C kliens csatlakozott! Cím: {addr}")
            
            with client_lock:
                c_client_socket = c
                
        except socket.error:
            print("[SOCKET] Hiba a kapcsolat elfogadásakor.")
            break


# Függvény az automatikus böngésző megnyitáshoz
def megnyit_bongeszo():
    # Várunk 1.5 másodpercet, hogy a Flask biztosan felálljon
    time.sleep(1.5)
    print("[RENDSZER] Böngésző automatikus megnyitása...")
    webbrowser.open("http://127.0.0.1:8081")


if __name__ == '__main__':
    # 1. Elindítjuk a Socket szervert egy háttérszálon
    socket_szal = threading.Thread(target=socket_szerver_futatasa, daemon=True)
    socket_szal.start()

    # 2. Elindítjuk a böngészőmegnyitó funkciót egy másik háttérszálon
    bongeszo_szal = threading.Thread(target=megnyit_bongeszo, daemon=True)
    bongeszo_szal.start()

    # 3. Elindítjuk a Flask webszervert a főszálon (localhost:8081)
    app.run(host='127.0.0.1', port=8081, debug=True, use_reloader=False)
