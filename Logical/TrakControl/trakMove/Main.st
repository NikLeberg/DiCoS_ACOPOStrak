
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
	
	//FB_couple.Command := mcACPTRAK_COUPLE_OBJ_SET;
	
	//FB_gearin.Master 			:= ADR(gDummyAxis);
	//FB_gearin.RatioNumerator 	:= 1; // synchrone 1:1 Bewegung
	//FB_gearin.RatioDenominator 	:= 1;
	//FB_gearin.Acceleration 		:= 0.0; // nutze Maximalerte des Slaves
	//FB_gearin.Deceleration 		:= 0.0;
	//FB_gearin.Jerk 				:= 0.0;
	//FB_gearin.BufferMode 		:= mcABORTING;
	//FB_gearin.MasterValueSource := mcVALUE_ACTUAL;
	
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
	
	FB_createConvoy.Parameters.NegativeOffset := 0.0;
	FB_createConvoy.Parameters.PositiveOffset := 0.2;
	FB_createConvoy.Parameters.Separable := FALSE;
	FB_createConvoy.Parameters.Elastic := TRUE;
	
	FB_add2Convoy.Parameters.CouplingMode := mcACPTRAK_COUPL_DIST;
	FB_add2Convoy.Parameters.Elastic := TRUE;
	FB_add2Convoy.AdvancedParameters.Velocity := 4.0;
	FB_add2Convoy.AdvancedParameters.Acceleration := 20.0;
	FB_add2Convoy.AdvancedParameters.Deceleration := 20.0;
	FB_add2Convoy.AdvancedParameters.TargetDistance := 0.126;
	
	FB_read1.ValueSource := mcVALUE_ACTUAL;
	FB_read2.ValueSource := mcVALUE_ACTUAL;
	
	
	// alle FBs deaktivieren
	FB_move.Execute 	:= FALSE;
	FB_couple.Execute 	:= FALSE;
	FB_gearin.Execute 	:= FALSE;
	FB_moveVel.Execute 	:= FALSE;
	FB_moveCyc.Enable 	:= FALSE;
	FB_createConvoy.Execute := FALSE;
	FB_read1.Enable 	:= FALSE;
	FB_read2.Enable 	:= FALSE;
	
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
			// erstelle ein Convoy
			FB_createConvoy.Axis := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_createConvoy.Execute := TRUE;
			// Weiter wenn Convoy erstellt wurde
			IF FB_createConvoy.Done THEN
				FB_createConvoy.Execute := FALSE;
				coupleStep := coupleStepSETOBJ2;
			END_IF;
			// DEBUG: Skip
			//coupleStep := coupleStepCOUPLE;
			// MANUAL
			
		coupleStepSETOBJ2:
			// TEST
			FB_read1.Axis := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_read2.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_read1.Enable := TRUE;
			FB_read2.Enable := TRUE;
			// New
			FB_add2Convoy.Parameters.ReferenceShuttle := ADR(trakAsmb.shuttles[dummyFirst].axis);
			FB_add2Convoy.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			FB_add2Convoy.Execute := TRUE;
			// OLD
			// Kopplungsobjekt an erstes Shuttle hängen
			//FB_couple.Axis := ADR(trakAsmb.shuttles[dummySecond].axis);
			//FB_couple.CouplingObjectName := 'couplingLoad';
			//FB_couple.Execute := TRUE;
			// Weiter wenn an Objekt angeschlossen.
			IF FB_add2Convoy.Done THEN
				FB_add2Convoy.Execute := FALSE;
				coupleStep := coupleStepDONE;
			END_IF;
			
		coupleStepCOUPLE:
			// Achsen synchronisieren bez. tatsächlich Koppeln.
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
	FB_createConvoy();
	FB_add2Convoy();
	FB_read1();
	FB_read2();
	
	distance := FB_read1.CyclicPosition - FB_read2.CyclicPosition;
	
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

