module part2(iResetn,iPlotBox,iBlack,iColour,iLoadX,iXY_Coord,iClock,oX,oY,oColour,oPlot,oDone);
   parameter X_SCREEN_PIXELS = 8'd160;
   parameter Y_SCREEN_PIXELS = 7'd120;

   input wire iResetn, iPlotBox, iBlack, iLoadX;
   input wire [2:0] iColour;
   input wire [6:0] iXY_Coord;
   input wire 	    iClock;
   output wire [7:0] oX;         // VGA pixel coordinates
   output wire [6:0] oY;

   output wire [2:0] oColour;     // VGA pixel colour (0-7)
   output wire 	     oPlot;       // Pixel draw enable
   output wire       oDone;       // goes high when finished drawing frame

  wire [2:0] state;
  wire [14:0] counter;

  FSM u1(iResetn, iPlotBox, iBlack, iLoadX, iClock, state, counter);
  Datapath u2(iResetn, state, iClock, iXY_Coord, iBlack, iPlotBox, iLoadX, iColour, counter, oX, oY, oColour, oPlot, oDone);

endmodule

module FSM (

  input reset,
  input plotbox,
  input black,
  input loadx,
  input Clock,
  output [2:0] state,
  output [14:0] counter_out
);

  reg [2:0] y_Q, Y_D;
  localparam A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100, F=3'b101;
  localparam s1 = 4'b1111;
  localparam s2 = 15'b100101100000000;
  reg [14:0] counter; 


  always @(*)
  begin: state_table
      case (y_Q)
          A: begin //basically waiting for loadx to go high so we can store x in register
            if (black)
              Y_D = E;
            else if (loadx)
              Y_D = B; //We can load the x cord into register 
            else 
               Y_D = A;
          end

          B: begin //load x cord
            if (black)
              Y_D = E;
            else if (~loadx) 
              Y_D = C; //X should now go to memory
            else 
               Y_D = B;
          end

          C: begin //bascailyl waiting for loadx to go high so we can store y in register
            if (black)
              Y_D = E;
            else if (plotbox)
              Y_D = D; //We can load the y cord and colour into register
            else 
               Y_D = C;
          end

          D: begin //load y cord and colour
            if (black || ~plotbox)
              Y_D = E;
            else 
               Y_D = D;
          end
          
          E: begin 
            //Plot with colour and x and y if black is on at this point plot black
            // Can only enter this state is black is on --> we have default values for this
            // If black is off --> this means our X and Y and Colour are in memory   
            if (counter == s1 && ~black)
              Y_D = F; //goes to this state after plotting to trigger done
            else if (counter == s2 && black)
              Y_D = F; //goes to this state after plotting to trigger done
            else 
               Y_D = E;
          end
          F: begin
            Y_D = A;
          end
          default: Y_D = A;
      endcase
  end

  always @(posedge Clock or posedge reset)
  begin: state_FFs
      if (reset)
        begin
          y_Q <= A; // Reset state to A
        end
      else
          y_Q <= Y_D;
  end
  assign state = y_Q;

  always @(posedge Clock or posedge reset) begin
      if (reset) begin
          counter <= 0;
      end
      else begin
          // Update counter based on certain conditions
        if (y_Q == E) begin
          counter <= counter + 1;
          if (counter == s1 && ~black && y_Q == E) // Check if all 16 pixels are plotted
          counter <= 0; 
          else if (counter == s2 && black && y_Q == E)
          counter <= 0;
        end
      end
  end
  assign counter_out = counter;
endmodule

module Datapath(
    input reset, 
    input [2:0] state,
    input clock,
    input [6:0] iXY_Coord,
    input black,
    input plotbox,
    input loadx,
    input [2:0] iColour,
    input [14:0] counter,
    output [7:0] oX,
    output [6:0] oY,
    output [2:0] oColour,
    output oPlot,
    output oDone
);

  reg [7:0] oX_reg, oX_reg_temp;
  reg [6:0] oY_reg, oY_reg_temp;
  reg [2:0] oColour_reg;     
  reg oPlot_reg;
  reg oDone_reg;
  localparam A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100, F = 3'b101;

  always @(posedge clock or posedge reset) begin
    if (reset)
      oDone_reg <= 1'b0;
    case (state)
      B: begin
        oX_reg <= iXY_Coord;
      end
      
      D: begin
        oY_reg <= iXY_Coord;
        oColour_reg <= iColour;
      end

      E: begin
        if (~black) begin
          oColour_reg <= iColour;
          oX_reg_temp <= oX_reg + (counter % 4);
          oY_reg_temp <= oY_reg + (counter / 4);
        end
        else if (black) begin
          oColour_reg <= 3'b0;
          oX_reg_temp <= oX_reg + (counter % 160);
          oY_reg_temp <= oY_reg + (counter / 120);
        end 
      end

      F:begin
        oDone_reg <= 1'b1;
      end
      endcase
  end
  assign oX = oX_reg_temp; 
  assign oY = oY_reg_temp;
  assign oColour = oColour_reg;
  assign oPlot = oPlot_reg;
  assign oDone = oDone_reg;
endmodule


