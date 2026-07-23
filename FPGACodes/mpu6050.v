module mpu6050 (
    input  wire        clk400khz,
    input  wire        rst,
    inout  wire        sda,
    output wire        scl,

    // Kiolvasott 16-bites nyers gyorsulásmérő adatok (2-es komplementer formátum)
    output reg signed [15:0] accel_x,
    output reg signed [15:0] accel_y,
    output reg signed [15:0] accel_z,

    // Kiolvasott 16-bites nyers giroszkóp adatok (2-es komplementer formátum)
    output reg signed [15:0] gyro_x,
    output reg signed [15:0] gyro_y,
    output reg signed [15:0] gyro_z
);

    // Belső jelek az i2c_master modulhoz
    reg  [7:0] data_to_send;
    wire [7:0] data_to_receive;
    reg        start;
    wire       ready;

    // Az i2c_master példányosítása
    i2c_master u_i2c (
        .clk     (clk400khz),
        .rst     (rst),
        .sda     (sda),
        .scl     (scl),
        .data_in (data_to_send),
        .data_out(data_to_receive),
        .start   (start),
        .ready   (ready)
    );

    // FSM Állapotok (5 bites állapotszámláló a 27 állapot kezeléséhez)
    localparam IDLE           = 5'd0,
               // 1. CONFIG (0x1A -> 0x05)
               CFG_DEV_ADDR   = 5'd1,
               CFG_REG_ADDR   = 5'd2,
               CFG_DATA       = 5'd3,
               // 2. GYRO_CONFIG (0x1B -> 0x08)
               GYRO_DEV_ADDR  = 5'd4,
               GYRO_REG_ADDR  = 5'd5,
               GYRO_DATA      = 5'd6,
               // 3. ACCEL_CONFIG (0x1C -> 0x00)
               ACC_DEV_ADDR   = 5'd7,
               ACC_REG_ADDR   = 5'd8,
               ACC_DATA       = 5'd9,
               // 4. OLVASÁS ELŐKÉSZÍTÉSE (0x3B regiszter megcímzése)
               READ_DEV_WR    = 5'd10,
               READ_REG_ADDR  = 5'd11,
               READ_DEV_RD    = 5'd12,
               // 5. GYORSULÁSMÉRŐ ADATOK KIOLVASÁSA (0x3B - 0x40)
               FETCH_AX_H     = 5'd13,
               FETCH_AX_L     = 5'd14,
               FETCH_AY_H     = 5'd15,
               FETCH_AY_L     = 5'd16,
               FETCH_AZ_H     = 5'd17,
               FETCH_AZ_L     = 5'd18,
               // 6. HŐMÉRSÉKLET ÁTLÉPÉSE (0x41 - 0x42)
               FETCH_TEMP_H   = 5'd19,
               FETCH_TEMP_L   = 5'd20,
               // 7. GIROSZKÓP ADATOK KIOLVASÁSA (0x43 - 0x48)
               FETCH_GX_H     = 5'd21,
               FETCH_GX_L     = 5'd22,
               FETCH_GY_H     = 5'd23,
               FETCH_GY_L     = 5'd24,
               FETCH_GZ_H     = 5'd25,
               FETCH_GZ_L     = 5'd26;

    reg [4:0] state;
    
    // Ideiglenes regiszterek a felső (MSB) bájtok eltárolásához
    reg [7:0] ax_h, ay_h, az_h;
    reg [7:0] gx_h, gy_h, gz_h;

    always @(posedge clk400khz or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            start        <= 1'b0;
            data_to_send <= 8'd0;
            accel_x      <= 16'd0;
            accel_y      <= 16'd0;
            accel_z      <= 16'd0;
            gyro_x       <= 16'd0;
            gyro_y       <= 16'd0;
            gyro_z       <= 16'd0;
            ax_h         <= 8'd0;
            ay_h         <= 8'd0;
            az_h         <= 8'd0;
            gx_h         <= 8'd0;
            gy_h         <= 8'd0;
            gz_h         <= 8'd0;
        end else begin
            case (state)

                IDLE: begin
                    if (ready) begin
                        data_to_send <= 8'hD0; // MPU6050 I2C Írási cím
                        start        <= 1'b1;
                        state        <= CFG_DEV_ADDR;
                    end
                end

                // --- 1. CONFIG (0x1A -> 0x05: DLPF Beállítása) ---
                CFG_DEV_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h1A; // Regiszter cím
                        start        <= 1'b1;
                        state        <= CFG_REG_ADDR;
                    end
                end

                CFG_REG_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h05; // Adat
                        start        <= 1'b1;
                        state        <= CFG_DATA;
                    end
                end

                // --- 2. GYRO_CONFIG (0x1B -> 0x08: +/- 500 deg/s) ---
                CFG_DATA: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'hD0;
                        start        <= 1'b1;
                        state        <= GYRO_DEV_ADDR;
                    end
                end

                GYRO_DEV_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h1B;
                        start        <= 1'b1;
                        state        <= GYRO_REG_ADDR;
                    end
                end

                GYRO_REG_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h08;
                        start        <= 1'b1;
                        state        <= GYRO_DATA;
                    end
                end

                // --- 3. ACCEL_CONFIG (0x1C -> 0x00: +/- 2g) ---
                GYRO_DATA: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'hD0;
                        start        <= 1'b1;
                        state        <= ACC_DEV_ADDR;
                    end
                end

                ACC_DEV_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h1C;
                        start        <= 1'b1;
                        state        <= ACC_REG_ADDR;
                    end
                end

                ACC_REG_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h00; // Méréshatár: +/- 2g
                        start        <= 1'b1;
                        state        <= ACC_DATA;
                    end
                end

                // --- 4. OLVASÁS KEZDŐCÍMÉNEK BEÁLLÍTÁSA (0x3B: ACCEL_XOUT_H) ---
                ACC_DATA: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'hD0;
                        start        <= 1'b1;
                        state        <= READ_DEV_WR;
                    end
                end

                READ_DEV_WR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'h3B; // ACCEL_XOUT_H regiszter címe
                        start        <= 1'b1;
                        state        <= READ_REG_ADDR;
                    end
                end

                READ_REG_ADDR: begin
                    start <= 1'b0;
                    if (ready) begin
                        data_to_send <= 8'hD1; // MPU6050 Olvasási cím
                        start        <= 1'b1;
                        state        <= READ_DEV_RD;
                    end
                end

                // --- 5. GYORSULÁSMÉRŐ ADATOK FOGADÁSA ---
                READ_DEV_RD: begin
                    start <= 1'b0;
                    if (ready) begin
                        ax_h  <= data_to_receive; // ACCEL_XOUT_H
                        start <= 1'b1;
                        state <= FETCH_AX_H;
                    end
                end

                FETCH_AX_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        accel_x <= {ax_h, data_to_receive}; // ACCEL_X 16-bit
                        start   <= 1'b1;
                        state   <= FETCH_AX_L;
                    end
                end

                FETCH_AX_L: begin
                    start <= 1'b0;
                    if (ready) begin
                        ay_h  <= data_to_receive; // ACCEL_YOUT_H
                        start <= 1'b1;
                        state <= FETCH_AY_H;
                    end
                end

                FETCH_AY_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        accel_y <= {ay_h, data_to_receive}; // ACCEL_Y 16-bit
                        start   <= 1'b1;
                        state   <= FETCH_AY_L;
                    end
                end

                FETCH_AY_L: begin
                    start <= 1'b0;
                    if (ready) begin
                        az_h  <= data_to_receive; // ACCEL_ZOUT_H
                        start <= 1'b1;
                        state <= FETCH_AZ_H;
                    end
                end

                FETCH_AZ_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        accel_z <= {az_h, data_to_receive}; // ACCEL_Z 16-bit
                        start   <= 1'b1;
                        state   <= FETCH_AZ_L;
                    end
                end

                // --- 6. HŐMÉRSÉKLET BÁJTOKBÓL VALÓ ATUGRÁS ---
                FETCH_AZ_L: begin
                    start <= 1'b0;
                    if (ready) begin
                        start <= 1'b1;
                        state <= FETCH_TEMP_H;
                    end
                end

                FETCH_TEMP_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        start <= 1'b1;
                        state <= FETCH_TEMP_L;
                    end
                end

                // --- 7. GIROSZKÓP ADATOK FOGADÁSA ---
                FETCH_TEMP_L: begin
                    start <= 1'b0;
                    if (ready) begin
                        gx_h  <= data_to_receive; // GYRO_XOUT_H
                        start <= 1'b1;
                        state <= FETCH_GX_H;
                    end
                end

                FETCH_GX_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        gyro_x <= {gx_h, data_to_receive}; // GYRO_X 16-bit
                        start  <= 1'b1;
                        state  <= FETCH_GX_L;
                    end
                end

                FETCH_GX_L: begin
                    start <= 1'b0;
                    if (ready) begin
                        gy_h  <= data_to_receive; // GYRO_YOUT_H
                        start <=  1'b1;
                        state <= FETCH_GY_H;
                    end
                end

                FETCH_GY_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        gyro_y <= {gy_h, data_to_receive}; // GYRO_Y 16-bit
                        start  <= 1'b1;
                        state  <= FETCH_GY_L;
                    end
                end

                FETCH_GY_L: begin
                    start <= 1'b0;
                    if (ready) begin
                        gz_h  <= data_to_receive; // GYRO_ZOUT_H
                        start <= 1'b1;
                        state <= FETCH_GZ_H;
                    end
                end

                FETCH_GZ_H: begin
                    start <= 1'b0;
                    if (ready) begin
                        gyro_z <= {gz_h, data_to_receive}; // GYRO_Z 16-bit
                        
                        // Összes (14) bájt kiolvasása kész, ciklus újraindítása 0x3B-ről:
                        data_to_send <= 8'hD0;
                        start        <= 1'b1;
                        state        <= READ_DEV_WR;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule