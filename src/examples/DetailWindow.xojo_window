#tag DesktopWindow
Begin DesktopWindow DetailWindow
   Backdrop        =   0
   BackgroundColor =   &cFFFFFF
   Composite       =   False
   DefaultLocation =   2
   FullScreen      =   False
   HasBackgroundColor=   False
   HasCloseButton  =   True
   HasFullScreenButton=   True
   HasMaximizeButton=   True
   HasMinimizeButton=   True
   HasTitleBar     =   True
   Height          =   400
   ImplicitInstance=   False
   MacProcID       =   0
   MaximumHeight   =   32000
   MaximumWidth    =   32000
   MenuBar         =   0
   MenuBarVisible  =   False
   MinimumHeight   =   200
   MinimumWidth    =   300
   Resizeable      =   True
   Title           =   "Detail"
   Type            =   0
   Visible         =   True
   Width           =   500
   Begin DesktopLabel TitleLabel
      AllowAutoDeactivate=   True
      Bold            =   True
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   24
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   False
      Left            =   16
      LockBottom      =   False
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      Multiline       =   False
      Scope           =   2
      Selectable      =   False
      TabIndex        =   0
      TabPanelIndex   =   0
      TabStop         =   False
      Text            =   "Title"
      TextAlignment   =   0
      TextColor       =   &c000000
      Tooltip         =   ""
      Top             =   16
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   468
   End
   Begin DesktopTextArea BodyArea
      AllowAutoDeactivate=   True
      AllowFocusRing  =   True
      AllowSpellChecking=   True
      AllowStyledText =   False
      AllowTabs       =   False
      Bold            =   False
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   280
      HideSelection   =   True
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   False
      Left            =   16
      LockBottom      =   True
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      ReadOnly        =   False
      Scope           =   2
      ScrollbarHorizontal=   False
      ScrollBarVertical=   True
      TabIndex        =   1
      TabPanelIndex   =   0
      TabStop         =   True
      Text            =   ""
      Top             =   52
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   468
   End
   Begin DesktopButton SaveButton
      AllowAutoDeactivate=   True
      Bold            =   False
      Cancel          =   False
      Caption         =   "Save"
      Default         =   True
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   24
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   False
      Left            =   400
      LockBottom      =   True
      LockedInPosition=   False
      LockLeft        =   False
      LockRight       =   True
      LockTop         =   False
      MacButtonStyle  =   0
      Scope           =   2
      TabIndex        =   2
      TabPanelIndex   =   0
      TabStop         =   True
      Tooltip         =   ""
      Top             =   360
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   80
   End
   Begin DesktopButton CancelButton
      AllowAutoDeactivate=   True
      Bold            =   False
      Cancel          =   True
      Caption         =   "Cancel"
      Default         =   False
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   24
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   False
      Left            =   308
      LockBottom      =   True
      LockedInPosition=   False
      LockLeft        =   False
      LockRight       =   True
      LockTop         =   False
      MacButtonStyle  =   0
      Scope           =   2
      TabIndex        =   3
      TabPanelIndex   =   0
      TabStop         =   True
      Tooltip         =   ""
      Top             =   360
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   80
   End
End
#tag EndDesktopWindow

#tag WindowCode
	#tag Event
		Sub Opening()
		  // Window is opening — called after controls are initialised.
		  // If data was passed via LoadItem(), it is already set here.
		End Sub
	#tag EndEvent

	#tag Event
		Sub Close()
		  // Window is closing — clean up if needed.
		End Sub
	#tag EndEvent

	#tag Event
		Sub Resized()
		  LayoutControls()
		End Sub
	#tag EndEvent

	#tag Method, Flags = &h0
		Sub LoadItem(title As String, body As String)
		  // Call this BEFORE Show or ShowModal to pre-populate the window.
		  // Pattern for non-singleton windows: create, load, show.
		  //   Var w As New DetailWindow
		  //   w.LoadItem("My Title", "Some text")
		  //   w.Show          ' non-blocking
		  //   ' -- or --
		  //   w.ShowModal     ' blocks until window closes
		  mTitle = title
		  mBody = body
		  Me.Title = If(title <> "", title, "Detail")
		  TitleLabel.Text = title
		  BodyArea.Text = body
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub LayoutControls()
		  TitleLabel.Left   = 16
		  TitleLabel.Top    = 16
		  TitleLabel.Width  = Me.Width - 32

		  BodyArea.Left     = 16
		  BodyArea.Top      = 52
		  BodyArea.Width    = Me.Width - 32
		  BodyArea.Height   = Me.Height - 52 - 48

		  SaveButton.Top    = Me.Height - 32
		  SaveButton.Left   = Me.Width - 96
		  CancelButton.Top  = Me.Height - 32
		  CancelButton.Left = Me.Width - 192
		End Sub
	#tag EndMethod

	#tag Property, Flags = &h21
		Private mTitle As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mBody As String
	#tag EndProperty

#tag EndWindowCode

#tag Events SaveButton
	#tag Event
		Sub Pressed()
		  // Read back edited values before closing.
		  mTitle = TitleLabel.Text
		  mBody = BodyArea.Text
		  Close()
		End Sub
	#tag EndEvent
#tag EndEvents

#tag Events CancelButton
	#tag Event
		Sub Pressed()
		  Close()
		End Sub
	#tag EndEvent
#tag EndEvents

#tag ViewBehavior
	#tag ViewProperty
		Name="Name"
		Visible=true
		Group="ID"
		InitialValue=""
		Type="String"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Interfaces"
		Visible=true
		Group="ID"
		InitialValue=""
		Type="String"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Super"
		Visible=true
		Group="ID"
		InitialValue=""
		Type="String"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Width"
		Visible=true
		Group="Size"
		InitialValue="500"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Height"
		Visible=true
		Group="Size"
		InitialValue="400"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Title"
		Visible=true
		Group="Frame"
		InitialValue="Detail"
		Type="String"
		EditorType=""
	#tag EndViewProperty
#tag EndViewBehavior
