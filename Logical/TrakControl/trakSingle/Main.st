
PROGRAM _INIT
	// Initialsiere alle FBs
	FB_move.Velocity      	:= 0.8;
	FB_move.Acceleration  	:= 10.0;
	FB_move.Deceleration  	:= 10.0;
	FB_move.Jerk          	:= 0.0;
	FB_move.BufferMode    	:= mcABORTING;
	FB_move.AdvancedParameters.StartDirection     := mcDIR_UNDEFINED;
	FB_move.AdvancedParameters.EndDirection       := mcDIR_POSITIVE;
	FB_move.AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
	
	FB_readSet.ValueSource 		:= mcVALUE_SET;
	FB_readActual.ValueSource	:= mcVALUE_ACTUAL;
	

	// alle FBs deaktivieren
	FB_move.Execute 	:= FALSE;
	FB_readSet.Enable 	:= FALSE;
	FB_readActual.Enable:= FALSE;
	
	// Initiale Zustände setzen
	trakSingle.cmd.goABB := FALSE;
	trakSingle.cmd.goDelta := FALSE;
	trakSingle.cmd.read := FALSE;
	trakSingle.state.atABB := FALSE;
	trakSingle.state.atDelta := FALSE;
	
END_PROGRAM

PROGRAM _CYCLIC
	// Lese die Position aus.
	FB_readSet.Enable    := trakSingle.cmd.read;
	FB_readActual.Enable := trakSingle.cmd.read;
	FB_readSet.Axis 	 := ADR(trakAsmb.shuttles[0].axis);
	FB_readActual.Axis 	 := ADR(trakAsmb.shuttles[0].axis);
	
	// Bewege Shuttle zu ABB oder Delta Position per FSM
	CASE intSingleStep OF
		singleStepIDLE:
			// Warte auf Fahrbefehl
			IF trakSingle.cmd.goABB THEN
				intSingleStep := singleStepMOVE_ABB;
			ELSIF trakSingle.cmd.goDelta THEN
				intSingleStep := singleStepMOVE_DELTA;
			END_IF;
			
		singleStepMOVE_ABB:
			// Starte Bewegung zur ABB Position
			FB_move.Axis := ADR(trakAsmb.shuttles[0].axis);
			FB_move.Sector := ADR(gSecMajor);
			FB_move.Position := posABB;
			FB_move.Execute := TRUE;
			trakSingle.state.atDelta := FALSE;
			intSingleStep := singleStepWAIT_ABB;
		
		singleStepWAIT_ABB:
			// Warte bis Position erreicht
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				trakSingle.state.atABB := TRUE;
				intSingleStep := singleStepIDLE;
			END_IF;
			
		singleStepMOVE_DELTA:
			// Starte Bewegung zur Delta Position
			FB_move.Axis := ADR(trakAsmb.shuttles[0].axis);
			FB_move.Sector := ADR(gSecMajor);
			FB_move.Position := posDelta;
			FB_move.Execute := TRUE;
			trakSingle.state.atABB := FALSE;
			intSingleStep := singleStepWAIT_DELTA;
		
		singleStepWAIT_DELTA:
			// Warte bis Position erreicht
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				trakSingle.state.atDelta := TRUE;
				intSingleStep := singleStepIDLE;
			END_IF;
		
	END_CASE;		
	
	// Rufe alle FBs zyklisch auf, werden aber nur berechnet wenn "Enable" oder "Execute" aktiv.
	FB_move();
	FB_readSet();
	FB_readActual();
	
	positionSet := FB_readSet.CyclicPosition;
	positionActual := FB_readActual.CyclicPosition;
	
	trakSingle.state.moving := FB_move.Busy;
	 
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

