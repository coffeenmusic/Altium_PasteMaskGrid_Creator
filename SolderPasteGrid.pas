{..............................................................................}
{ Summary Pin Package Lengths Importer script.
{         The ImportPinPackLenForm is the main form.                           }
{         You need a Pin Package Length Data CSV file to import                }
{         onto a Component symbol                                              }
{                                                                              }
{ To use the script:                                                           }
{  1/ Select the component in schematic that is going to be updated            }
{  2/ Execute the ImportPins procedure and the Pins Importer dialog appears    }
{  3/ Click on browse button to load in the CSV file of schematic pins data.   }
{  4/ Click Run Button                                                         }
{  5/ Check lengths in schematic:                                              }
{            - Right click on schematic symbol and Select Properties           }
{            - In the new window click 'Edit Pins...' in the botttom left      }
{            - This should allow you to review the pin package lengths         }
{  Note: Built on Altium 16.1 so menu options and locations may have changed   }
{..............................................................................}

{..............................................................................}
procedure SolderPasteGrid();
const
    INTERN2MIL = 10000;  // Internal Unit Conversion to mils
    MIN_PASTE_GRID = 40; // Minimum Grid Size in mils
    MIN_PASTE_GAP = 7;   // Minimum spacing between paste grids
var
    Board         : IPCB_Board;
    Iterator      : IPCB_SpatialIterator;
    Pad           : IPCB_Primitive;
    Padcache      : TPadCache;
    Pad_Layer     : TPCBString;
    Pad_x, Pad_y  : Double;
    Pad_h, Pad_w  : Double;
    Pad_Rotation  : Float;
    Pad_Rect      : TCoordRect;
    Pad_L         : TPCBString;
    Pad_R         : TPCBString;
    Pad_T         : TPCBString;
    Pad_B         : TPCBString;
    Paste_Exp     : Double;
    Fill          : IPCB_Fill;
    Grid_x_cnt    : Integer;
    Grid_y_cnt    : Integer;
    Grid_x_pad    : Integer;
    Grid_y_pad    : Integer;
    xorigin, yorigin : Double;
    i, j          : Integer;
    fill_x1, fill_x2, fill_y1, fill_y2 : Double;
begin
    // Retrieve the current board
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    // Create the iterator that will look for Component Body objects only
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(ePadObject));
    Iterator.AddFilter_LayerSet(MkSet(eTopLayer));
    Iterator.AddFilter_Method(eProcessAll);

    xorigin := Board.XOrigin;
    yorigin := Board.YOrigin;

    Pad := Iterator.FirstPCBObject;
    While (Pad <> Nil) Do
    Begin


        If (Pad.Selected) Then
        Begin
            Pad_x := Pad.x - xorigin;
            Pad_y := Pad.y - yorigin;
            Pad_h := Pad.TopXSize;
            Pad_w := Pad.TopYSize;
            Pad_Layer := Layer2String(Pad.Layer);
            Pad_Rotation := Pad.Rotation;
            Pad_Rect := Pad.BoundingRectangle;
            //Pad_L := IntToStr(Pad_Rect.Left - xorigin);
            //Pad_R := IntToStr(Pad_Rect.Right - xorigin);
            //Pad_T := IntToStr(Pad_Rect.Top - yorigin);
            //Pad_B := IntToStr(Pad_Rect.Bottom - yorigin);
            Paste_Exp := Pad.PasteMaskExpansion;

            // Set Paste Mask Expansion To Remove Current Paste Mask
            If (Pad_Layer = 'Top Layer') and (Pad_x = 0) and (Pad_y = 0) Then
            Begin
                Padcache := Pad.GetState_Cache;
                Padcache.PasteMaskExpansionValid := eCacheManual;

                If (Paste_Exp > -Pad_w) or (Paste_Exp > -Pad_h) Then
                Begin
                     If (Pad_w > Pad_h) Then
                     Begin
                          Padcache.PasteMaskExpansion := -Pad_w;
                     End
                     Else
                     Begin
                          Padcache.PasteMaskExpansion := -Pad_h;
                     End;
                End;

                Pad.SetState_Cache := Padcache;
            End;

            // Get grid counts
            Grid_x_cnt := Floor((Pad_w/INTERN2MIL)/MIN_PASTE_GRID);
            Grid_y_cnt := Floor((Pad_h/INTERN2MIL)/MIN_PASTE_GRID);

            Grid_x_pad := 0; Grid_y_pad := 0;

            While (Grid_x_pad < MIN_PASTE_GAP*INTERN2MIL) or (Grid_y_pad < MIN_PASTE_GAP*INTERN2MIL) Do
            Begin
                 // Get Grid padding
                 Grid_x_pad := (Pad_w - (Grid_x_cnt*MIN_PASTE_GRID*INTERN2MIL))/(Grid_x_cnt+1);
                 Grid_y_pad := (Pad_h - (Grid_y_cnt*MIN_PASTE_GRID*INTERN2MIL))/(Grid_y_cnt+1);

                 If (Grid_x_pad < MIN_PASTE_GAP*INTERN2MIL) Then
                 Begin
                      Grid_x_cnt := Grid_x_cnt - 1;
                 End;
                 If (Grid_y_pad < MIN_PASTE_GAP*INTERN2MIL) Then
                 Begin
                      Grid_y_cnt := Grid_y_cnt - 1;
                 End;

                 // Error Exit
                 If Grid_x_cnt <= 0 Then Exit;
                 If Grid_y_cnt <= 0 Then Exit;
            End;

            FOR i := 0 TO Grid_x_cnt - 1 DO
            BEGIN
                 FOR j := 0 TO Grid_y_cnt - 1 DO
                 BEGIN
                     // Create Fill
                     fill_x1 := Grid_x_pad*(i+1) + i*MIN_PASTE_GRID*INTERN2MIL - (Pad_w/2);
                     fill_x2 := Grid_x_pad*(i+1) + (i+1)*MIN_PASTE_GRID*INTERN2MIL - (Pad_w/2);
                     fill_y1 := Grid_y_pad*(j+1) + j*MIN_PASTE_GRID*INTERN2MIL - (Pad_h/2);
                     fill_y2 := Grid_y_pad*(j+1) + (j+1)*MIN_PASTE_GRID*INTERN2MIL - (Pad_h/2);

                     Fill := PCBServer.PCBObjectFactory(eFillObject, eNoDimension, eCreate_Default);
                     Fill.X1Location := fill_x1 + xorigin;
                     Fill.Y1Location := fill_y1 + yorigin;
                     Fill.X2Location := fill_x2 + xorigin;
                     Fill.Y2Location := fill_y2 + yorigin;
                     Fill.Layer := eTopPaste;
                     Fill.Rotation := 0;

                     // Add a new Fill into the PCB design database.
                     Board.AddPCBObject(Fill);
                 END;
            END;

            // Refresh the PCB document
            ResetParameters;
            AddStringParameter('Action', 'All');
            RunProcess('PCB:Zoom');
        End;


        Pad := Iterator.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(Iterator);
end;

