with System;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Unchecked_Conversion;
with Ada.Text_IO; use Ada.Text_IO;
with ECS.Event_Manager; use ECS.Event_Manager;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with ECS.Event;

package body Window is

   package IC renames Interfaces.C; use IC;
   package ICS renames IC.Strings;


   -- Declare the event manager
   Manager : aliased ECS.Event_Manager.Platform_Event_Handler;

   -- EDITED 11/26/24 to add WM_KEYDOWN and WM_LBUTTONDOWN
   function Wnd_Proc (H_Wnd   : HWND; 
                     Msg     : IC.unsigned; 
                     W_Param : WPARAM; 
                     L_Param : LPARAM) return LRESULT is
   begin
      case Msg is
         when WM_DESTROY =>
            Post_Quit_Message (0);

         when WM_PAINT =>
            null;

         when WM_KEYDOWN =>
         declare
            KeyCode : ECS.Event.Byte := ECS.Event.Byte(W_Param);
            Event   : ECS.Event.Event_T :=
            (Source    => 0,
               EventType => ECS.Event.KeyPress,
               Data      => (KeyCode    => KeyCode,
                           MouseX     => 0,
                           MouseY     => 0,
                           Additional => (others => 0)));
         begin
            Emit_Event(Manager, Event);
         end;

         when WM_LBUTTONDOWN =>
         declare
            L_Param_U : Interfaces.C.unsigned_long := Interfaces.C.unsigned_long(L_Param);
            MouseX    : Integer := Integer(L_Param_U and 16#FFFF#);
            MouseY    : Integer := Integer((L_Param_U / 16#10000#) and 16#FFFF#);
            MouseEvent : ECS.Event.Event_T :=
              (Source    => 0,
               EventType => ECS.Event.MouseClick,
               Data      => (KeyCode    => 0,
                             MouseX     => MouseX,
                             MouseY     => MouseY,
                             Additional => (others => 0)));
         begin
            Emit_Event(Manager, MouseEvent);
         end;


         when others =>
            return Def_Window_Proc(H_Wnd, Msg, W_Param, L_Param);
      end case;
      return 0;
   end Wnd_Proc;


   -- Creates a new window instance and returns it to the caller
   function New_Window(Width : Interfaces.C.int; Height : Interfaces.C.int; Title : Unbounded_String) return Window_Access is
      WC       : aliased WNDCLASS;
      Res_Atom : ATOM;
      Window   : Window_Access := new Window_T;
   begin
      -- Initialize the WNDCLASS struct
      WC.Lp_fn_Wnd_Proc    := Wnd_Proc'Access;
      WC.H_Instance        := Get_H_Instance;
      WC.Lpsz_Class_Name   := TO_LPCSTR(ICS.New_String("SampleWindowClass"));
      WC.H_br_Background   := HBRUSH(Get_Stock_Object(COLOR_BACKGROUND));

      -- Register the window class with the win32 API
      Res_ATOM := Register_Class(WC'Access);
      if Res_Atom = 0 then
         raise Program_Error with "Failed to register window class.";
      end if;

      -- Create the window
      Window.Handle := Create_Window(
         Dw_Ex_Style    => 0,
         Lp_Class_Name  => WC.Lpsz_Class_Name,
         Lp_Window_Name => TO_LPCSTR(ICS.New_String(To_String(Title))),
         Dw_Style       => WS_OVERLAPPEDWINDOW,
         X              => 0,  -- defines the window start coordinate. 
         Y              => 0,
         Width          => Width,
         Height         => Height,
         H_Wnd_Parent   => System.Null_Address,
         H_Menu         => System.Null_Address,
         H_Instance     => WC.H_Instance,
         Lp_Param       => System.Null_Address
      );


      -- Window properties
      Window.Width := Width;
      Window.Height := Height;
      Window.Title := Title;
     
      -- Show the window
      declare
         SW_Result : Boolean;
         UW_Result : Boolean;
      begin   
         SW_Result := Show_Window(Window.Handle, SW_SHOW);
         UW_Result := Update_Window(Window.Handle);
      end;
      return Window;

   end New_Window;



   procedure Draw_Buffer(Window : in out Window_T; Buffer : System.Address) is
      Bmi_Reset : Byte_Array (0 .. BITMAPINFO'Size / 8 - 1) := (others => 0);
      Bmi : aliased BITMAPINFO with Address => Bmi_Reset'Address;

      Result : Interfaces.C.int;
   begin

      Bmi.bmiHeader.biSize            := BITMAPINFOHEADER'Size / 8;
      Bmi.bmiHeader.biWidth           := Window.Width;   
      Bmi.bmiHeader.biHeight          := -Window.Height;
      Bmi.bmiHeader.biPlanes          := 1;
      Bmi.bmiHeader.biBitCount        := 32;
      Bmi.bmiHeader.biCompression     := BI_RGB;
      Bmi.bmiHeader.biSizeImage       := 0;
      Bmi.bmiHeader.biXPelsPerMeter   := 0;
      Bmi.bmiHeader.biYPelsPerMeter   := 0;
      Bmi.bmiHeader.biClrUsed         := 0;
      Bmi.bmiHeader.biClrImportant    := 0;

      Result := Stretch_DIBits(
         H_Dc           => GetDC(Window.Handle),
         X_Dest         => 0,
         Y_Dest         => 0,
         Dest_Width     => Window.Width,
         Dest_Height    => Window.Height,
         X_Src          => 0,
         Y_Src          => 0,
         Src_Width      => Window.Width,
         Src_Height     => Window.Height,
         Bits           => Buffer,
         Bitmap_Info    => Bmi'Unchecked_Access,
         Usage          => DIB_RGB_COLORS,
         Rop            => SRCCOPY
      );

      if Result = 0 then
         Put_Line("StretchDIBits failed.");
      end if;
   end Draw_Buffer;

end Window;