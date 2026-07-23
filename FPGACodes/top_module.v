`timescale 1ns / 1ps

module top_module(
    input clk100mhz,
    input [3:0] btn,
    output [6:0] a_to_g,
    output dp,
    output [3:0] an,
    output JA1,
    input JA2,
    output JA3,
    // ÚJ: Hozzáadjuk a többi motorvezérlő kimenetet is a top modulhoz,
    // hogy az FPGA lábaira ki tudjuk vezetni őket a korábbi logika alapján
    output JB0,
    output JB1,
    output JC0
);
    wire [3:0] btnd;
    wire clk50hz, clk190, clk25mhz;
    wire clr;
    assign clr = btn[3];
    wire rdrf, rdrf_clr, FE;
    wire [7:0] rx_data;
    wire pwm_ja3;
    wire clk_400khz;
    
    // ÚJ: Belső huzalok a többi motor kimenetnek
    wire pwm_jb0, pwm_jb1, pwm_jc0; 

   // wire [15:0] x_rec;

    clk_divider U1(.clk(clk100mhz), .clr(clr),.clk50hz(clk50hz),.clk25mhz(clk25mhz),.clk190hz(clk190), .clk400khz(clk_400khz));
    debounce4 U2(.inp(btn), .cclk(clk190), .clr(clr), .outp(btnd));
    uart_rx U6(.RxD(JA2),.clk(clk25mhz),.clr(clr),.rdrf_clr(rdrf_clr),.rdrf(rdrf), .rx_data(rx_data), .FE(FE));
    test_rx_ctrl U7 (.clk(clk25mhz),.clr(clr), .rdrf(rdrf), .rdrf_clr(rdrf_clr));
    x7segb U5(.x(rx_data[3:0]),.cclk(clk190), .clr(clr), .a_to_g(a_to_g), .an(an), .dp(dp));
    //test_tx_ctrl U4(.clk(clk25mhz), .clr(clr), .go(btnd[0]), .tdre(tdre), .ready(ready));
    //uart_tx U3(.clk(clk25mhz), .clr(clr), .tx_data(sw), .ready(ready), .tdre(tdre), .TxD(TxD));
    
    // MÓDOSÍTVA: Bekötöttük a pwm_generate modul összes kimenetét a belső jelekre
    pwm_generate U8(
        .clk(clk100mhz), 
        .data(rx_data[3:0]), 
        .JA3(pwm_ja3),
        .JB0(pwm_jb0),
        .JB1(pwm_jb1),
        .JC0(pwm_jc0)
    );
    wire signed [15:0] accel_x_out;
    wire signed [15:0] accel_y_out;
    wire signed [15:0] accel_z_out;

    // Meglévő vezetékek a giroszkóphoz
    wire signed [15:0] gyro_x_out;
    wire signed [15:0] gyro_y_out;
    wire signed [15:0] gyro_z_out;
mpu6050 U9 (
        .clk400khz (clk_400khz),     // A legyártott 400 kHz-es órajel
        .rst       (sys_rst),        // Rendszer reset
        .sda       (i2c_sda),        // Fizikai SDA láb
        .scl       (i2c_scl),        // Fizikai SCL láb

        // Kiolvasott gyorsulásmérő adatok (ÚJ)
        .accel_x   (accel_x_out),    // X gyorsulás
        .accel_y   (accel_y_out),    // Y gyorsulás
        .accel_z   (accel_z_out),    // Z gyorsulás

        // Kiolvasott giroszkóp adatok
        .gyro_x    (gyro_x_out),     // X szögsebesség
        .gyro_y    (gyro_y_out),     // Y szögsebesség
        .gyro_z    (gyro_z_out)      // Z szögsebesség
    );
    pid_controller U10 (.clk(clk100mhz), .accel_x(accel_x_out),.accel_y(accel_y_out), .accel_z(accel_z_out), .gyro_x(gyro_x_out), .gyro_y(gyro_y_out), .gyro_z(gyro_z_out));
    // ÚJ: A belső PWM jeleket rákötjük a top modul fizikai kimeneteire
    assign JA3 = pwm_ja3;
    assign JB0 = pwm_jb0;
    assign JB1 = pwm_jb1;
    assign JC0 = pwm_jc0;

endmodule