#tag Class
Protected Class MyClass
Inherits Object
	#tag Event, Description = "Fired when the item count changes. Define this event to let subclasses or windows react."
		Sub CountChanged(newCount As Integer)
		End Sub
	#tag EndEvent

	#tag Method, Flags = &h0
		Sub Constructor(name As String)
		  mName = name
		  mCount = 0
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Greet() As String
		  Return "Hello from " + mName
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub IncrementCount()
		  mCount = mCount + 1
		  RaiseEvent CountChanged(mCount)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Function Create(name As String) As MyClass
		  // Shared (class-level) factory method — called as MyClass.Create("foo")
		  // Flags = &h0 (Public). Add "Private " prefix + keep &h0 for Private Shared,
		  // or use &h1 for Protected Shared.
		  Return New MyClass(name)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub InternalHelper()
		  // Protected — visible to subclasses, not to callers outside the hierarchy
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FormatName() As String
		  // Private — not visible outside this class
		  Return mName.Uppercase
		End Function
	#tag EndMethod

	#tag Property, Flags = &h0
		MyProperty As Integer
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected ProtectedProp As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mName As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCount As Integer
	#tag EndProperty

	#tag Constant, Name = kMaxItems, Type = Integer, Dynamic = False, Default = "100", Scope = Public
	#tag EndConstant

	#tag Note, Name = DesignNotes
		MyClass demonstrates the standard block layout for a Xojo class file.

		Block ordering within a .xojo_code file (must be preserved exactly):
		  1. #tag Event definitions  (custom events this class fires)
		  2. #tag Method blocks       (Constructor first, then others)
		  3. #tag Property blocks
		  4. #tag Constant blocks
		  5. #tag Note blocks
		  6. #tag ViewBehavior        (always last — do not add anything after it)

		Access modifier flags (used on both Method and Property tags):
		  &h0   Public
		  &h1   Protected
		  &h21  Private
		The modifier keyword in the declaration line ("Protected", "Private") must
		match the flag value — both are required.

		Shared methods: add the "Shared " keyword before "Function" or "Sub".
		The flag value is the same as for instance methods (&h0 / &h1 / &h21).

		Constants use a different format from methods and properties — all
		metadata is on the #tag Constant line itself, nothing inside the block:
		  #tag Constant, Name = kMax, Type = Integer, Dynamic = False, Default = "100", Scope = Public
		  #tag EndConstant
		Valid Scope values: Public, Protected, Private.
		Valid Type values: String, Integer, Double, Boolean, Color.

		Custom events: #tag Event inside a class body defines an event that the
		class can RaiseEvent. Consumers add an event handler with
		AddEventImplementation in the IDE or by editing the .xojo_window file.
	#tag EndNote

	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
