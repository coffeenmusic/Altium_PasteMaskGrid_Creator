{..............................................................................}
{ Summary Solder Paste Grid script.                                            }
{         Creates a Footprint's Paste Mask as a Grid instead of                }
{         just matching the pad size w/ expansion setting                      }
{                                                                              }
{                                                                              }
{ To use the script:                                                           }
{  1/ Select the footprint's center pad.                                       }
{  2/ Execute the script                                                       }
{                                                                              }
{ TODO:                                                                        }
{  - Handle rotation                                                           }
{..............................................................................}
Interface

Type
  TTextForm = class(TForm)
    bRun          : TButton;
    txtMinGridSize  : TEdit;
    txtMinGap : TEdit;
    lblMinGridSize: TLabel;
    lblMinGap: TLabel;
  End;

Var
  TextForm: TTextForm;

Implementation


// Sets the paste mask expansion to a negative value less than the max pad
// dimension to remove it from the footprint.
function RemoveExistingPaste(Pad: IPCB_Primitive);
var
    Padcache      : TPadCache;
    Pad_h, Pad_w  : Double;
    Paste_Exp     : Double;
begin
    Pad_h := Pad.TopXSize;
    Pad_w := Pad.TopYSize;
    Paste_Exp := Pad.PasteMaskExpansion;

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
end;

function CreatePasteGrid(Board: IPCB_Board, Pad: IPCB_Primitive, Min_Grid_Size: Integer, Min_Gap: Integer);
const
    INTERN2MIL = 10000;  // Internal Unit Conversion to mils
var
    Grid_x_cnt, Grid_y_cnt                : Integer;
    Grid_x_pad, Grid_y_pad                : Integer;
    Pad_h, Pad_w                          : Double;
    i, j                                  : Integer;
    Fill                                  : IPCB_Fill;
    fill_x1, fill_x2, fill_y1, fill_y2    : Double;
    xorigin, yorigin                      : Double;
    Pad_Rotation                          : Double;
begin
    xorigin := Board.XOrigin;
    yorigin := Board.YOrigin;

    Pad_Rotation := Pad.Rotation;

    If (Pad_Rotation = 90) or (Pad_Rotation = 270) Then
    Begin // If Rotated, swap width and height
        Pad_h := Pad.TopXSize;
        Pad_w := Pad.TopYSize;
    End
    Else
    Begin
        Pad_h := Pad.TopYSize;
        Pad_w := Pad.TopXSize;
    End;




    // Get grid counts
    Grid_x_cnt := Floor((Pad_w/INTERN2MIL)/Min_Grid_Size);
    Grid_y_cnt := Floor((Pad_h/INTERN2MIL)/Min_Grid_Size);

    Grid_x_pad := 0; Grid_y_pad := 0;

    While (Grid_x_pad < Min_Gap*INTERN2MIL) or (Grid_y_pad < Min_Gap*INTERN2MIL) Do
    Begin
         // Get Grid padding
         Grid_x_pad := (Pad_w - (Grid_x_cnt*Min_Grid_Size*INTERN2MIL))/(Grid_x_cnt+1);
         Grid_y_pad := (Pad_h - (Grid_y_cnt*Min_Grid_Size*INTERN2MIL))/(Grid_y_cnt+1);

         If (Grid_x_pad < Min_Gap*INTERN2MIL) Then
         Begin
              Grid_x_cnt := Grid_x_cnt - 1;
         End;
         If (Grid_y_pad < Min_Gap*INTERN2MIL) Then
         Begin
              Grid_y_cnt := Grid_y_cnt - 1;
         End;

         // Error Exit
         If Grid_x_cnt <= 0 Then Exit;
         If Grid_y_cnt <= 0 Then Exit;
    End;

    For i := 0 To Grid_x_cnt - 1 Do
    Begin
         For j := 0 To Grid_y_cnt - 1 Do
         Begin
              // Create Fill
              fill_x1 := Grid_x_pad*(i+1) + i*Min_Grid_Size*INTERN2MIL - (Pad_w/2);
              fill_x2 := Grid_x_pad*(i+1) + (i+1)*Min_Grid_Size*INTERN2MIL - (Pad_w/2);
              fill_y1 := Grid_y_pad*(j+1) + j*Min_Grid_Size*INTERN2MIL - (Pad_h/2);
              fill_y2 := Grid_y_pad*(j+1) + (j+1)*Min_Grid_Size*INTERN2MIL - (Pad_h/2);

              Fill := PCBServer.PCBObjectFactory(eFillObject, eNoDimension, eCreate_Default);
              Fill.X1Location := fill_x1 + xorigin;
              Fill.Y1Location := fill_y1 + yorigin;
              Fill.X2Location := fill_x2 + xorigin;
              Fill.Y2Location := fill_y2 + yorigin;
              Fill.Layer := eTopPaste;
              Fill.Rotation := 0;

              // Add a new Fill into the PCB design database.
              Board.AddPCBObject(Fill);
         End;
    End;

    // Refresh the PCB document
    ResetParameters;
    AddStringParameter('Action', 'All');
    RunProcess('PCB:Zoom');
End;

{..............................................................................}
function SolderPasteGrid(Min_Grid_Size: Integer, Min_Gap: Integer);
var
    Board         : IPCB_Board;
    Iterator      : IPCB_SpatialIterator;
    Pad           : IPCB_Primitive;
    Pad_Layer     : TPCBString;
    Pad_x, Pad_y  : Double;
    xorigin, yorigin : Double;

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
            Pad_Layer := Layer2String(Pad.Layer);

            If (Pad_Layer = 'Top Layer') and (Pad_x = 0) and (Pad_y = 0) Then
            Begin
                 // Set Paste Mask Expansion To Remove Current Paste Mask
                 RemoveExistingPaste(Pad);

                 CreatePasteGrid(Board, Pad, Min_Grid_Size, Min_Gap);
            End;
        End;

        Pad := Iterator.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(Iterator);
end;




procedure TTextForm.bRunClick(Sender: TObject);
begin
     Close;
     SolderPasteGrid(txtMinGridSize.Text, txtMinGap.Text);
end;

Procedure RunSolderPasteGrid;
Begin
    TextForm.ShowModal;
End;

