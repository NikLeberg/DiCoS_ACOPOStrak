
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
	
	FB_couple.Command := mcACPTRAK_COUPLE_OBJ_SET;
	
	FB_gearin.RatioNumerator 	:= 1; // synchrone 1:1 Bewegung
	FB_gearin.RatioDenominator 	:= 1;
	FB_gearin.Acceleration 		:= 0.0; // nutze Maximalerte des Slaves
	FB_gearin.Deceleration 		:= 0.0;
	FB_gearin.Jerk 				:= 0.0;
	FB_gearin.BufferMode 		:= mcABORTING;
	FB_gearin.MasterValueSource := mcVALUE_ACTUAL;
	
	FB_moveVel.Velocity      	:= 0.8;
	FB_moveVel.RouteVelocity	:= 0.8;
	FB_moveVel.Acceleration  	:= 2.0;
	FB_moveVel.Deceleration  	:= 2.0;
	FB_moveVel.Jerk          	:= 0.0;
	FB_moveVel.BufferMode    	:= mcABORTING;
	FB_moveVel.AdvancedParameters.StartDirection     := mcDIR_UNDEFINED;
	FB_moveVel.AdvancedParameters.EndDirection       := mcDIR_POSITIVE;
	FB_moveVel.AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
	
	FB_moveCyc.InterpolationMode 	:= mcIPLM_DEFAULT;
	FB_moveCyc.CyclicPosition 		:= 1.0;
	FB_moveCyc.AdvancedParameters.Velocity 		:= 0.8;
	FB_moveCyc.AdvancedParameters.Acceleration 	:= 2.0;
	FB_moveCyc.AdvancedParameters.Deceleration 	:= 2.0;
	FB_moveCyc.AdvancedParameters.Jerk			:= 0.0;
	
	FB_read1.ValueSource := mcVALUE_ACTUAL;
	FB_read2.ValueSource := mcVALUE_ACTUAL;
	FB_read3.ValueSource := mcVALUE_SET;
	FB_read4.ValueSource := mcVALUE_SET;
	
	
	// alle FBs deaktivieren
	FB_move.Execute 	:= FALSE;
	FB_couple.Execute 	:= FALSE;
	FB_gearin.Execute 	:= FALSE;
	FB_moveVel.Execute 	:= FALSE;
	FB_moveCyc.Enable 	:= FALSE;
	FB_read1.Enable 	:= FALSE;
	FB_read2.Enable 	:= FALSE;
	FB_read3.Enable 	:= FALSE;
	FB_read4.Enable 	:= FALSE;
	
	dummyFirst := 1;
	dummySecond := 0;
	
END_PROGRAM

PROGRAM _CYCLIC
	// Durchlaufe eine FSM um zwei Shuttles zu verbinden.
	CASE coupleStep OF
		coupleStepWAIT:
			// Warte auf Ready + Befehl.
			IF (trakMove.cmd.test AND trakAsmb.state.ready) THEN
				coupleStep := coupleStepSENDPOS1;
				trakMove.cmd.test := FALSE;
			END_IF;
			
		coupleStepSENDPOS1:
			// Starte Bewegung des ersten Shuttles.
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := 0.426;
			FB_move.Axis := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				coupleStep := coupleStepSENDPOS2;
			END_IF;
			
		coupleStepSENDPOS2:
			// Starte Bewegung des zweiten Shuttles.
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := 0.3;
			FB_move.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				coupleStep := coupleStepSETOBJ1;
			END_IF;
			
		coupleStepSETOBJ1:
			// Manueller Schritt, setze coupleStep per PV Watch auf coupleStepSETOBJ2
			// DEBUG: Skip
			//coupleStep := coupleStepCOUPLE;
			
		coupleStepSETOBJ2:
			// TEST
			FB_read1.Axis := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_read2.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_read1.Enable := TRUE;
			FB_read2.Enable := TRUE;
			FB_read3.Axis := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_read4.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_read3.Enable := TRUE;
			FB_read4.Enable := TRUE;
			// Kopplungsobjekt an zweites Shuttle h?ngen
			FB_couple.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_couple.CouplingObjectName := 'couplingLoad';
			FB_couple.Execute := TRUE;
			// Weiter wenn an Objekt angeschlossen.
			IF FB_couple.Done THEN
				FB_couple.Execute := FALSE;
				coupleStep := coupleStepCOUPLE;
			END_IF;
			
		coupleStepCOUPLE:
			// Achsen synchronisieren bez. tats?chlich Koppeln.
			FB_gearin.Master := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_gearin.Slave := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_gearin.Execute := TRUE;
			// Wenn Kopplung aktiv ist, dann sind wir fertig.
			IF FB_gearin.Active THEN
				coupleStep := coupleStepDONE;
			END_IF;
			
		coupleStepDONE:
			// Master Shuttle bewegen.
			FB_moveCyc.Axis := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_moveCyc.Enable := TRUE;
		// Weiter wenn Bewegung abgeschlossen.
		//IF FB_moveCyc.Done THEN
		//	FB_moveAdd.Execute := FALSE;
		//	coupleStep := coupleStepWAIT;
		//END_IF;
			
	END_CASE;
	
	// Rufe alle FBs zyklisch auf, werden aber nur berechnet wenn "Enable" oder "Execute" aktiv.
	FB_move();
	FB_couple();
	FB_gearin();
	FB_moveVel();
	FB_moveCyc();
	FB_read1();
	FB_read2();
	FB_read3();
	FB_read4();
	
	distanceActual := FB_read1.CyclicPosition - FB_read2.CyclicPosition;
	distanceSet := FB_read3.CyclicPosition - FB_read4.CyclicPosition;
	
	// Enable der FBs deaktivieren wenn Busy Signal geht oder Fehler ansteht.
	//IF EDGENEG(FB_move.Busy) OR FB_move.Error THEN
	//	FB_move.Execute := FALSE;
	//END_IF;
	//IF EDGENEG(FB_couple.Busy) OR FB_couple.Error THEN
	//	FB_couple.Execute := FALSE;
	//END_IF;
	
	// Sobald Fehler in GearIn (keine Sanchronisation mehr) auftritt, dann stoppe komplettes Assembly
	IF FB_gearin.Error THEN
		trakAsmb.cmd.power := FALSE;
	END_IF;		
	 
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

