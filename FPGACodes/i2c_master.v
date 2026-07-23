module i2c_master (
    input  wire       clk,             // Ide a clk400khz-et kell kötnöd
    input  wire       rst,             // Aktív magas reset (a név alapján)
    inout  wire       sda,             // Kétirányú I2C adatvonal
    output reg        scl,             // I2C órajel kimenet
    input  wire [7:0] data_in,         // A küldendő 8 bites adat (data_to_send)
    output reg  [7:0] data_out,        // A fogadott 8 bites adat (data_to_receive)
    input  wire       start,           // Indító jel
    output reg        ready            // FSM készen áll
);

    // Állapotok definíciói az ábrád alapján
    localparam IDLE      = 4'd0,
               START1    = 4'd1,
               START2    = 4'd2,
               HOLD      = 4'd3,
               DATA1     = 4'd4,
               DATA2     = 4'd5,
               DATA3     = 4'd6,
               DATA4     = 4'd7,
               DATA_END  = 4'd8,
               STOP1     = 4'd9,
               STOP2     = 4'd10;

    reg [3:0] current_state, next_state;
    reg [3:0] bit_reg;        // Bitszámláló (0-tól 8-ig)
    reg [7:0] shift_reg;      // Léptetőregiszter a küldéshez
    
    // SDA belső vezérlő jelei (mivel inout, tri-state logikát kell alkalmazni)
    reg  sda_out_en;          // 1: az FPGA hajtja az SDA-t, 0: elengedi (bemenet/pull-up)
    reg  sda_out_val;         // Az FPGA által kiadott érték az SDA-n
    
    // Tri-state puffer az SDA vonalhoz
    assign sda = (sda_out_en && !sda_out_val) ? 1'b0 : 1'bz;

    // 1. Állapotregiszter és belső regiszterek (Szekvenciális blokk)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            bit_reg       <= 4'd0;
            shift_reg     <= 8'd0;
            data_out      <= 8'd0;
        end else begin
            current_state <= next_state;
            
            // Ha IDLE-ben startot kapunk, betöltjük az adatot a léptetőregiszterbe
            if (current_state == IDLE && start) begin
                shift_reg <= data_in;
            end
            
            // Bitszámláló növelése és adat léptetése a bitciklus végén (DATA4)
            if (current_state == DATA4) begin
                if (bit_reg == 4'd8) begin
                    bit_reg <= 4'd0;
                end else begin
                    bit_reg   <= bit_reg + 1'b1;
                    shift_reg <= {shift_reg[6:0], 1'b0}; // Balra léptetés
                end
            end
            
            // Adat beolvasása a DATA3 állapotban (amikor az SCL magas és stabil)
            // Itt feltételezzük, hogy olvasási fázisban vagyunk (pl. a címzés után)
            if (current_state == DATA3 && bit_reg < 4'd8) begin
                data_out <= {data_out[6:0], sda};
            end
        end
    end

    // 2. Következő állapot logikája (Kombinációs blokk)
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = START1;
            end
            START1:  next_state = START2;
            START2:  next_state = HOLD;
            HOLD:    next_state = DATA1; // A start után automatikusan küldjük az adatot
            
            DATA1:   next_state = DATA2;
            DATA2:   next_state = DATA3;
            DATA3:   next_state = DATA4;
            DATA4: begin
                if (bit_reg < 4'd8) next_state = DATA1; // Megy a következő bitre (összesen 8 bit + ACK/NACK)
                else                next_state = DATA_END;
            end
            
            DATA_END: next_state = STOP1; // Az adat/ACK lefutása után lezárjuk a buszt
            STOP1:    next_state = STOP2;
            STOP2:    next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // 3. Kimenetek (SCL és SDA) vezérlése az ábra hullámformái alapján
    always @(*) begin
        // Alapértelmezett biztonságos értékek (lebegő busz)
        ready        = 1'b0;
        scl          = 1'b1;
        sda_out_en   = 1'b0; 
        sda_out_val  = 1'b1;

        case (current_state)
            IDLE: begin
                ready       = 1'b1;
                scl         = 1'b1;
                sda_out_en  = 1'b0; // Elengedve (High-Z), a külső pull-up felhúzza 1-re
            end
            
            // START feltétel generálása
            START1: begin
                scl         = 1'b1;
                sda_out_en  = 1'b1;
                sda_out_val = 1'b0; // SDA lehúzása alacsonyra, miközben SCL magas
            end
            START2: begin
                scl         = 1'b0; // SCL is lemegy alacsonyra
                sda_out_en  = 1'b1;
                sda_out_val = 1'b0;
            end
            HOLD: begin
                scl         = 1'b0;
                sda_out_en  = 1'b1;
                sda_out_val = 1'b0;
            end
            
            // Adatbitek kezelése (DATA1-DATA4)
            DATA1: begin
                scl = 1'b0;
                if (bit_reg < 4'd8) begin
                    sda_out_en  = 1'b1;
                    sda_out_val = shift_reg[7]; // MSB bit kihelyezése az SDA-ra
                end else begin
                    sda_out_en  = 1'b0; // A 9. bitnél (ACK/NACK) elengedjük az SDA-t a slave-nek
                end
            end
            DATA2: begin
                scl = 1'b1; // SCL felugrik magasra
                if (bit_reg < 4'd8) begin
                    sda_out_en  = 1'b1;
                    sda_out_val = shift_reg[7];
                end else begin
                    sda_out_en  = 1'b0;
                end
            end
            DATA3: begin
                scl = 1'b1; // SCL magas marad (itt stabil az adat)
                if (bit_reg < 4'd8) begin
                    sda_out_en  = 1'b1;
                    sda_out_val = shift_reg[7];
                end else begin
                    sda_out_en  = 1'b0;
                end
            end
            DATA4: begin
                scl = 1'b0; // SCL visszaesik alacsonyra, felkészülés a következő bitre
                if (bit_reg < 4'd8) begin
                    sda_out_en  = 1'b1;
                    sda_out_val = shift_reg[7];
                end else begin
                    sda_out_en  = 1'b0;
                end
            end
            
            DATA_END: begin
                scl         = 1'b0;
                sda_out_en  = 1'b1;
                sda_out_val = 1'b0; // STOP előkészítése: SDA-t alacsonyra húzzuk
            end
            
            // STOP feltétel generálása
            STOP1: begin
                scl         = 1'b1; // SCL felmegy magasra
                sda_out_en  = 1'b1;
                sda_out_val = 1'b0; // SDA még alacsonyan van tartva
            end
            STOP2: begin
                scl         = 1'b1;
                sda_out_en  = 1'b0; // SDA-t elengedjük $\rightarrow$ felugrik magasra (STOP)
            end
        endcase
    end

endmodule