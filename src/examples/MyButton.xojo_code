#tag Class
Protected Class MyButton
Inherits DesktopButton
	#tag Event
		Sub Pressed()
		  // Handle button press
		  MessageBox(Caption + " was pressed")
		End Sub
	#tag EndEvent

	#tag Method, Flags = &h0
		Sub Reset()
		  Caption = "Button"
		End Sub
	#tag EndMethod

	#tag Property, Flags = &h0
		MyProperty As String = "default"
	#tag EndProperty

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
			Name="MyProperty"
			Visible=true
			Group="Behavior"
			InitialValue="default"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
