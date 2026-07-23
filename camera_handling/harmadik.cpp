#include <opencv2/opencv.hpp>
#include <iostream>
#include <cmath>
#include <vector>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <csignal>

#define BUFSIZE 1024
#define PORT_NO 2223
#define CQL 10

int sc;
int s;

void stop(int sig)
{
    close(s);
    close(sc);
    std::cout << "\nSzerver leĂˇllĂ­tva." << std::endl;
    exit(0);
}

using namespace cv;
using namespace std;

int main(int argc, char *argv[])
{
    // HĂˇlĂłzati vĂˇltozĂłk deklarĂˇciĂłja
    int bytes;
    int err;
    int flag;
    char on;
    char buffer[BUFSIZE];
    socklen_t server_size;
    socklen_t client_size;
    struct sockaddr_in server;
    struct sockaddr_in client;

    // InicializĂˇlĂˇs
    on = 1;
    flag = 0;
    server.sin_family = AF_INET;
    server.sin_addr.s_addr = INADDR_ANY;
    server.sin_port = htons(PORT_NO);
    server_size = sizeof server;
    client_size = sizeof client;
    signal(SIGINT, stop);
    signal(SIGTERM, stop);

    // Socket lĂ©trehozĂˇsa
    sc = socket(AF_INET, SOCK_STREAM, 0);
    if (sc < 0)
    {
        fprintf(stderr, "Socket creation error\n");
        exit(2);
    }
    setsockopt(sc, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
    setsockopt(sc, SOL_SOCKET, SO_KEEPALIVE, &on, sizeof on);

    err = bind(sc, (struct sockaddr *) &server, server_size);
    if (err < 0) {
        fprintf(stderr, "Binding error.\n");
        exit(3);
    }

    err = listen(sc, CQL);
    if (err < 0) {
        fprintf(stderr, "Listening error.\n");
        exit(4);
    }

    // --- HĂLĂ“ZATI CSATLAKOZĂS ---
    cout << "VĂˇrakozĂˇs a kliensre a " << PORT_NO << " porton..." << endl;
    s = accept(sc, (struct sockaddr *) &client, &client_size);
    if (s < 0) {
        fprintf(stderr, "Accepting error.\n");
        exit(5);
    }
    cout << "Kliens csatlakozott! Kamera indĂ­tĂˇsa..." << endl;

    VideoCapture cam(0);
    if (!cam.isOpened())
    {
        cout << "Hiba a kamera megnyitasakor!" << endl;    
        close(s);
        close(sc);
        return -1;
    }

    // KĂ©pfeldolgozĂˇsi mĂˇtrixok
    Mat frame, gray, blurred, grad_x, grad_y, abs_grad_x, abs_grad_y, sobel_edges, binary_edges;
    Mat detection_gray; // KĂĽlĂ¶n mĂˇtrix az objektumdetektĂˇlĂˇshoz
    
    int scale = 1;
    int delta = 0;
    int ddepth = CV_16S;

    // Objektum detektĂˇlĂł (StoptĂˇbla) betĂ¶ltĂ©se
    CascadeClassifier classifier("stop_sign/stop_sign_classifier_2.xml");
    if (classifier.empty()) {
        cout << "Hiba: Nem sikerĂĽlt betĂ¶lteni a stoptĂˇbla osztĂˇlyozĂłt!" << endl;
        close(s);
        close(sc);
        return -1;
    }

    // Vektor a detektĂˇlt objektumok (tĂ©glalapok) tĂˇrolĂˇsĂˇra
    vector<Rect> detected_objects;

    while(true)
    {
        cam >> frame;
        if (frame.empty()) {
            cout << "Ures kepkocka erkezett!" << endl;
            break;
        }
        
        int img_w = frame.cols;
        int img_h = frame.rows;
        int img_center_x = img_w / 2;

        // SzĂĽrkeĂˇrnyalatĂş konverziĂł (kĂ¶zĂ¶s alap mindkĂ©t feldolgozĂˇshoz)
        cvtColor(frame, gray, COLOR_BGR2GRAY);

        // ==========================================
        // A) OBJEKTUM DETEKTĂLĂS (StoptĂˇbla keresĂ©s)
        // ==========================================
        gray.copyTo(detection_gray);
        equalizeHist(detection_gray, detection_gray); // Hisztogram kiegyenlĂ­tĂ©s a jobb detektĂˇlĂˇsĂ©rt

        // KeresĂ©s futtatĂˇsa
        classifier.detectMultiScale(detection_gray, detected_objects, 1.1, 2, 0, Size(30, 30));

        // ==========================================
        // B) SĂVKĂ–VETĂ‰S Ă‰S SOBEL Ă‰LDETEKTĂLĂS
        // ==========================================
        GaussianBlur(gray, blurred, Size(5, 5), 0);
        
        Sobel(blurred, grad_x, ddepth, 1, 0, 3, scale, delta, BORDER_DEFAULT);
        Sobel(blurred, grad_y, ddepth, 0, 1, 3, scale, delta, BORDER_DEFAULT);

        convertScaleAbs(grad_x, abs_grad_x);
        convertScaleAbs(grad_y, abs_grad_y);
        addWeighted(abs_grad_x, 0.5, abs_grad_y, 0.5, 0, sobel_edges);

        threshold(sobel_edges, binary_edges, 60, 255, THRESH_BINARY);
        medianBlur(binary_edges, binary_edges, 5);

        // UI kimeneti kép előkészítése (az eredeti színes kép másolata, hogy a piros/zöld jelölések jól látszódjanak)
        Mat out = frame.clone();
        
        int y_bottom = img_h * 0.85; 
        int y_top = img_h * 0.55;    

        long long lx_bottom_sum = 0, rx_bottom_sum = 0;
        int l_bot_cnt = 0, r_bot_cnt = 0;

        long long lx_top_sum = 0, rx_top_sum = 0;
        int l_top_cnt = 0, r_top_cnt = 0;

        int window = 15;
        for (int y = 0; y < binary_edges.rows; y++) {
            bool is_bottom = (y > y_bottom - window && y < y_bottom + window);
            bool is_top = (y > y_top - window && y < y_top + window);

            if (!is_bottom && !is_top) continue;

            for (int x = 0; x < binary_edges.cols; x++) {
                if (binary_edges.at<uchar>(y, x) > 0) {
                    if (x < img_center_x) {
                        if (is_bottom) { lx_bottom_sum += x; l_bot_cnt++; }
                        else { lx_top_sum += x; l_top_cnt++; }
                    } else {
                        if (is_bottom) { rx_bottom_sum += x; r_bot_cnt++; }
                        else { rx_top_sum += x; r_top_cnt++; }
                    }
                    out.at<Vec3b>(y, x) = Vec3b(0, 0, 255); // Élek pirossal az 'out' képen
                }
            }
        }

        Point2d mid_bottom(img_center_x, y_bottom);
        Point2d mid_top(img_center_x, y_top);

        if (l_bot_cnt > 0 && r_bot_cnt > 0) {
            double avg_l = (double)lx_bottom_sum / l_bot_cnt;
            double avg_r = (double)rx_bottom_sum / r_bot_cnt;
            mid_bottom.x = (avg_l + avg_r) / 2.0;
        }
        if (l_top_cnt > 0 && r_top_cnt > 0) {
            double avg_l = (double)lx_top_sum / l_top_cnt;
            double avg_r = (double)rx_top_sum / r_top_cnt;
            mid_top.x = (avg_l + avg_r) / 2.0;
        }

        // Stabil zĂ¶ld kĂ¶zĂ©pvonal kirajzolĂˇsa
        line(out, mid_bottom, mid_top, Scalar(0, 255, 0), 4, 8);
        circle(out, mid_bottom, 6, Scalar(255, 0, 0), -1);
        circle(out, mid_top, 6, Scalar(255, 0, 0), -1);

        // KanyarodĂˇsi stratĂ©gia Ă©s kormĂˇnyzĂˇsi jel (elmozdulĂˇs)
        double steering_error = mid_top.x - img_center_x;

        // ==========================================
        // C) DETEKTĂLT TALĂLATOK KIRAJZOLĂSA (KĂ¶zĂ¶s UI)
        // ==========================================
        for (const auto& object : detected_objects) {
            rectangle(out, object, Scalar(0, 0, 255), 3);
            putText(out, "STOP", Point(object.x, object.y - 10), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(0, 0, 255), 2);
        }

        // ==========================================
        // D) ELSŐBBSÉGI ADATKÜLDÉS A KLIENSNEK
        // ==========================================
        string error_msg;
        
        if (!detected_objects.empty()) {
            // Elsőbbség: ha találtunk stop táblát, felülírjuk az üzenetet és "0\n"-t küldünk
            error_msg = "0\n";
        } else {
            // Ha nincs tábla, megy a normál sávtartó steering_error érték
            error_msg = to_string((int)steering_error) + "\n";
        }
        
        bytes = send(s, error_msg.c_str(), error_msg.length(), flag);
        if (bytes < 0) {
            cout << "A kliens lekapcsolĂłdott vagy kĂĽldĂ©si hiba tĂ¶rtĂ©nt." << endl;
            break;
        }

        // UI szĂ¶vegek összeállítása
        string direction = "EGYENESEN";
        if (steering_error > 15) direction = "JOBBRA KANYARODJ";
        else if (steering_error < -15) direction = "BALRA KANYARODJ";

        // Vizuális visszajelzés a képernyőn is a küldött parancsról
        string status_text;
        if (!detected_objects.empty()) {
            status_text = "STOP DETEKTALVA! Kuldve: 0";
            putText(out, status_text, Point(30, 50), FONT_HERSHEY_SIMPLEX, 0.8, Scalar(0, 0, 255), 2);
        } else {
            status_text = direction + " (Hiba: " + to_string((int)steering_error) + " px)";
            putText(out, status_text, Point(30, 50), FONT_HERSHEY_SIMPLEX, 0.8, Scalar(255, 255, 0), 2);
        }
        
        line(out, Point(img_center_x, 0), Point(img_center_x, img_h), Scalar(100, 100, 100), 1, LINE_AA);

        imshow("Savkovezeto es Kozepvonal", out);
        
        char key = (char)waitKey(30);
        if (key == 'q' || key == 27) break;
    } 

    close(s);
    close(sc);
    return 0;
}
