import pygame
import sys

# Pygame inicializálása
pygame.init()
pygame.joystick.init()

# Joystick ellenőrzése és inicializálása
if pygame.joystick.get_count() == 0:
    print("Nincs csatlakoztatva joystick!")
    sys.exit()

# Az első joystick kiválasztása és inicializálása
controller = pygame.joystick.Joystick(0)
controller.init()

print(f"Használt kontroller: {controller.get_name()}")

class Player(object):
    def __init__(self):
        self.player = pygame.rect.Rect((300, 400, 50, 50))
        self.color = "white"

    def move(self, x_speed, y_speed):
        self.player.move_ip((x_speed, y_speed))

    def change_color(self, color):
        self.color = color

    def draw(self, game_screen):
        pygame.draw.rect(game_screen, self.color, self.player)

player = Player()
clock = pygame.time.Clock()
screen = pygame.display.set_mode((800, 600))

LOOP = True
while LOOP:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            LOOP = False
        
        # Gombnyomások figyelése és kiírása
        if event.type == pygame.JOYBUTTONDOWN:
            print(f"Gomb lenyomva: {event.button}")
            if event.button == 0:
                player.change_color("green")
            elif event.button == 1:
                player.change_color("red")
            elif event.button == 2:
                player.change_color("blue")
                LOOP = False # Ha ki akarod léptetni a gombbal, hagyd bent
            elif event.button == 3:
                player.change_color("yellow")

    # Tengelyek értékeinek lekérése
    # Megjegyzés: A 0 és 1 általában a bal kar, a 2 és 3 a jobb kar (eszközfüggő)
    axis_x = controller.get_axis(3)
    axis_y = controller.get_axis(1)

    # Értékek kiírása a konzolra (f-stringgel formázva a tizedeseket)
    print(f"X tengely: {axis_x:.2f} | Y tengely: {axis_y:.2f}", end="\r")

    # Mozgás (sebesség szorzóval, ha túl lassú lenne a round miatt)
    # A round() segít, hogy csak akkor mozogjon, ha határozottan elmozdítod
    move_x = int(round(axis_x * 5))
    move_y = int(round(axis_y * 5))
    
    player.move(move_x, move_y)

    # Rajzolás
    screen.fill((0, 0, 0))
    player.draw(screen)
    pygame.display.update()
    
    clock.tick(60) # A 180 FPS nagyon sok, 60 általában elég és stabilabb

pygame.quit()
