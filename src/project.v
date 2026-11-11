/* Mini Galaga - version sencilla
 * Controles: izquierda, derecha, A para disparar
 * El contador muestra puntos del 0 al 9.
 */
`default_nettype none

module tt_um_Sergio_Galaxy (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena, clk, rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in[7], ui_in[3:0], uio_in};

    // Pantalla VGA
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    reg [1:0] R, G, B;
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    hvsync_generator vga (
        .clk(clk), .reset(~rst_n),
        .hsync(hsync), .vsync(vsync),
        .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
    );

    // Control de videojuego (no modificar gamepad_pmod.v)
    wire izquierda, derecha, boton_a, inicio;
    gamepad_pmod_single control (
        .rst_n(rst_n), .clk(clk),
        .pmod_data(ui_in[6]), .pmod_clk(ui_in[5]), .pmod_latch(ui_in[4]),
        .left(izquierda), .right(derecha), .a(boton_a), .start(inicio),
        .b(), .y(), .select(), .up(), .down(),
        .x(), .l(), .r(), .is_present()
    );

    // Variables del juego
    reg [9:0] nave_x;
    reg [9:0] bala_x, bala_y;
    reg bala_activa;
    reg [9:0] enemigo_x;
    reg enemigo_derecha;
    reg [2:0] vivos;
    reg [3:0] puntos;

    // La logica del juego se actualiza una vez por pantalla
    wire frame = (pix_x == 0 && pix_y == 0);
    wire [9:0] e0 = enemigo_x;
    wire [9:0] e1 = enemigo_x + 10'd100;
    wire [9:0] e2 = enemigo_x + 10'd200;

    wire bala_en_fila = bala_activa && (bala_y >= 10'd108) && (bala_y <= 10'd148);

    always @(posedge clk) begin
        if (!rst_n || inicio) begin
            nave_x <= 10'd300;
            bala_x <= 0;
            bala_y <= 0;
            bala_activa <= 0;
            enemigo_x <= 10'd100;
            enemigo_derecha <= 1;
            vivos <= 3'b111;
            puntos <= 0;
        end else if (frame) begin
            // Mover nave
            if (izquierda && nave_x > 10'd8)
                nave_x <= nave_x - 10'd4;
            else if (derecha && nave_x < 10'd600)
                nave_x <= nave_x + 10'd4;

            // Mover enemigos
            if (enemigo_derecha) begin
                if (enemigo_x < 10'd280)
                    enemigo_x <= enemigo_x + 10'd1;
                else
                    enemigo_derecha <= 0;
            end else begin
                if (enemigo_x > 10'd80)
                    enemigo_x <= enemigo_x - 10'd1;
                else
                    enemigo_derecha <= 1;
            end

            // Disparar y subir la bala
            if (!bala_activa && boton_a) begin
                bala_activa <= 1;
                bala_x <= nave_x + 10'd14;
                bala_y <= 10'd414;
            end else if (bala_activa) begin
                if (bala_y > 10'd8)
                    bala_y <= bala_y - 10'd8;
                else
                    bala_activa <= 0;
            end

            // Colisiones y contador
            if (bala_en_fila && vivos[0] && bala_x >= e0 && bala_x < e0 + 10'd30) begin
                vivos[0] <= 0;
                bala_activa <= 0;
                puntos <= (puntos == 9) ? 0 : puntos + 4'd1;
            end else if (bala_en_fila && vivos[1] && bala_x >= e1 && bala_x < e1 + 10'd30) begin
                vivos[1] <= 0;
                bala_activa <= 0;
                puntos <= (puntos == 9) ? 0 : puntos + 4'd1;
            end else if (bala_en_fila && vivos[2] && bala_x >= e2 && bala_x < e2 + 10'd30) begin
                vivos[2] <= 0;
                bala_activa <= 0;
                puntos <= (puntos == 9) ? 0 : puntos + 4'd1;
            end

            // Si destruye los tres, aparecen otra vez
            if (vivos == 0)
                vivos <= 3'b111;
        end
    end

    // Dibujos hechos con rectangulos
    wire nave = ((pix_x >= nave_x && pix_x < nave_x + 10'd32 &&
                  pix_y >= 10'd430 && pix_y < 10'd445) ||
                 (pix_x >= nave_x + 10'd10 && pix_x < nave_x + 10'd22 &&
                  pix_y >= 10'd420 && pix_y < 10'd430));

    wire bala = bala_activa && pix_x >= bala_x && pix_x < bala_x + 10'd4 &&
                pix_y >= bala_y && pix_y < bala_y + 10'd12;

    wire enemigos = (pix_y >= 10'd120 && pix_y < 10'd150) &&
                    ((vivos[0] && pix_x >= e0 && pix_x < e0 + 10'd30) ||
                     (vivos[1] && pix_x >= e1 && pix_x < e1 + 10'd30) ||
                     (vivos[2] && pix_x >= e2 && pix_x < e2 + 10'd30));

    // Contador de puntos con forma de numero (7 segmentos)
    reg [6:0] seg;
    always @(*) begin
        case (puntos)
            0: seg = 7'b1111110;
            1: seg = 7'b0110000;
            2: seg = 7'b1101101;
            3: seg = 7'b1111001;
            4: seg = 7'b0110011;
            5: seg = 7'b1011011;
            6: seg = 7'b1011111;
            7: seg = 7'b1110000;
            8: seg = 7'b1111111;
            9: seg = 7'b1111011;
            default: seg = 7'b1111110;
        endcase
    end

    wire numero =
        (seg[6] && pix_x >= 25 && pix_x < 55 && pix_y >= 20 && pix_y < 26) ||
        (seg[5] && pix_x >= 55 && pix_x < 61 && pix_y >= 26 && pix_y < 50) ||
        (seg[4] && pix_x >= 55 && pix_x < 61 && pix_y >= 50 && pix_y < 74) ||
        (seg[3] && pix_x >= 25 && pix_x < 55 && pix_y >= 74 && pix_y < 80) ||
        (seg[2] && pix_x >= 19 && pix_x < 25 && pix_y >= 50 && pix_y < 74) ||
        (seg[1] && pix_x >= 19 && pix_x < 25 && pix_y >= 26 && pix_y < 50) ||
        (seg[0] && pix_x >= 25 && pix_x < 55 && pix_y >= 47 && pix_y < 53);

    // Colores: nave verde, enemigos rojos, bala amarilla
    always @(posedge clk) begin
        if (!rst_n || !video_active)
            {R, G, B} <= 6'b000000;
        else if (numero)
            {R, G, B} <= 6'b111111; // Blancoa
        else if (nave)
            {R, G, B} <= 6'b001100; // Verde
        else if (bala)
            {R, G, B} <= 6'b111100; // Amarillo
        else if (enemigos)
            {R, G, B} <= 6'b110000; // Rojo
        else
            {R, G, B} <= 6'b000000; // Negro
    end
endmodule

`default_nettype wire
