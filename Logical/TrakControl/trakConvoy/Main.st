
PROGRAM _INIT
	// Initialsiere alle FBs
	FB_move.Velocity      	:= 1.5;
	FB_move.Acceleration  	:= 10.0;
	FB_move.Deceleration  	:= 10.0;
	FB_move.Jerk          	:= 0.0;
	FB_move.BufferMode    	:= mcABORTING;
	FB_move.AdvancedParameters.StartDirection     := mcDIR_UNDEFINED;
	FB_move.AdvancedParameters.EndDirection       := mcDIR_POSITIVE;
	FB_move.AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
	
	FB_moveVel.Velocity      	:= 1.5;
	FB_moveVel.Acceleration  	:= 10.0;
	FB_moveVel.Deceleration  	:= 10.0;
	FB_moveVel.Jerk          	:= 0.0;
	FB_moveVel.BufferMode    	:= mcABORTING;
	FB_moveVel.AdvancedParameters.StartDirection     := mcDIR_UNDEFINED;
	FB_moveVel.AdvancedParameters.EndDirection       := mcDIR_POSITIVE;
	FB_moveVel.AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
	
	FB_createConvoy.Parameters.NegativeOffset := 0.2;
	FB_createConvoy.Parameters.PositiveOffset := 0.2;
	FB_createConvoy.Parameters.Separable := FALSE;
	FB_createConvoy.Parameters.Elastic := TRUE;
	//FB_createConvoy.Parameters.MasterVelocityAdjustment := TRUE;
	//FB_createConvoy.Parameters.TargetDistDeceleration := 0.0;
	
	FB_add2Convoy.Parameters.CouplingMode := mcACPTRAK_COUPL_DIST;
	FB_add2Convoy.Parameters.Elastic := TRUE;
	FB_add2Convoy.AdvancedParameters.Velocity := 4.0;
	FB_add2Convoy.AdvancedParameters.Acceleration := 20.0;
	FB_add2Convoy.AdvancedParameters.Deceleration := 20.0;
	FB_add2Convoy.AdvancedParameters.TargetDistance := -0.09; //0.126;
	
	FB_readActMaster.ValueSource := mcVALUE_ACTUAL;
	FB_readActSlave.ValueSource  := mcVALUE_ACTUAL;
	FB_readSetMaster.ValueSource := mcVALUE_SET;
	FB_readSetSlave.ValueSource  := mcVALUE_SET;
	
	FB_ppCommand.ProcessPoint := ADR(gPPDepot);
	FB_ppCommand.Command := mcACPTRAK_BARRIER_ADD_TICKETS;
	FB_ppCommand.AdvancedParameters.TicketCount := 2;
	//FB_ppCommand.AdvancedParameters.TicketCount := 1;
	
	FB_ppGet.ProcessPoint := ADR(gPPDepot);
	FB_ppGet.AdvancedParameters.SelectionMode := mcACPTRAK_BARR_GET_SH_CLOSEST;
	FB_ppGet.Next := FALSE;
	
	
	// alle FBs deaktivieren
	FB_move.Execute 		:= FALSE;
	FB_moveVel.Execute 		:= FALSE;
	FB_createConvoy.Execute := FALSE;
	FB_add2Convoy.Execute	:= FALSE;
	FB_deleteConvoy.Execute := FALSE;
	FB_readSetMaster.Enable := FALSE;
	FB_readActMaster.Enable := FALSE;
	FB_readSetSlave.Enable 	:= FALSE;
	FB_readActSlave.Enable 	:= FALSE;
	FB_ppCommand.Execute 	:= FALSE;
	
	// auslesen der Depot PP immer aktivieren
	FB_ppGet.Enable := TRUE;
	
	// Startzustand
	fsmStep := STEP_RESET;
	shuttleResetCounter := 0;
	
END_PROGRAM

PROGRAM _CYCLIC
	// Durchlaufe eine FSM um zwei Shuttles zu koppeln.
	CASE fsmStep OF
		STEP_RESET:
			// Depot Barriere Schliessen
			FB_ppCommand.Command := mcACPTRAK_BARRIER_CLOSE;
			FB_ppCommand.Execute := TRUE;
			// Weiter wenn Kommando ausgeführt wurde
			IF FB_ppCommand.Done THEN
				FB_ppCommand.Execute := FALSE;
				// Weiter
				fsmStep := STEP_RESET_WAIT;
			END_IF;
			
		STEP_RESET_WAIT:
			// Warte bis Assembly ready.
			IF trakAsmb.state.ready THEN
				shuttleResetCounter := 0;
				fsmStep := STEP_RESET_MOVE;
			END_IF;
			
		STEP_RESET_MOVE:
			// Alle Shuttles im Assembly ins Depot bewegen.
			FB_moveVel.Sector := ADR(gSecFull);
			FB_moveVel.Position := 6.0; // Position ist hinterhalb des PP gPPDepot (ist bei pos 5.6)
			FB_moveVel.Axis := ADR(trakAsmb.shuttles[shuttleResetCounter].axis);
			FB_moveVel.Execute := TRUE;
			// Direkt weiter sobald Fahrbefehl aktiv, wird im Hintergrund weitergeführt.
			IF EDGEPOS(FB_moveVel.Active) THEN
				FB_moveVel.Execute := FALSE;
				fsmStep := STEP_RESET_NEXT;
			END_IF;
			
		STEP_RESET_NEXT:
			// Nächstes Shuttle senden.
			shuttleResetCounter := shuttleResetCounter + 1;
			// Wenn Zähler die Anzahl Shuttles erreicht hat, sind wir fertig mit allen Shuttles.
			// Ansonsten zum nächsten Shuttle.
			IF shuttleResetCounter = trakAsmb.shuttleCount THEN
				fsmStep := STEP_IDLE;
			ELSE
				fsmStep := STEP_RESET_MOVE;
			END_IF;
		
		STEP_IDLE:
			// Warte auf Ready + Befehl.
			IF (trakConvoy.cmd.prepare AND trakAsmb.state.ready) THEN
				trakConvoy.cmd.prepare := FALSE;
				fsmStep := STEP_WAIT_MASTER;
			END_IF;
			
		STEP_WAIT_MASTER:
			// Warte bis ein Shuttle hinter der Barriere wartet
			IF (FB_ppGet.Valid AND FB_ppGet.TotalCount <> 0) THEN
				// Shuttle gefunden, speichere Achse
				masterAxis := FB_ppGet.Axis;
				// Aktiviere lesen des Master Position
				FB_readSetMaster.Axis := ADR(masterAxis);
				FB_readSetMaster.Enable := TRUE;
				FB_readActMaster.Axis := ADR(masterAxis);
				FB_readActMaster.Enable := TRUE;
				// Weiter
				fsmStep := STEP_GET_MASTER;
			END_IF;
		
		STEP_GET_MASTER:
			// Löse ein Shuttle aus dem Depot
			FB_ppCommand.AdvancedParameters.TicketCount := 1;
			FB_ppCommand.Command := mcACPTRAK_BARRIER_ADD_TICKETS;
			FB_ppCommand.Execute := TRUE;
			// Weiter wenn Kommando ausgeführt wurde
			IF FB_ppCommand.Done THEN
				FB_ppCommand.Execute := FALSE;
				fsmStep := STEP_POS_MASTER;
			END_IF;
		
		STEP_POS_MASTER:
			// Sende neue Sollposition
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := trakConvoy.startPos;
			FB_move.Axis := ADR(masterAxis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				fsmStep := STEP_WAIT_SLAVE;
			END_IF;
		
		STEP_WAIT_SLAVE:
			// Warte bis ein Shuttle hinter der Barriere wartet
			IF (FB_ppGet.Valid AND FB_ppGet.TotalCount <> 0) THEN
				// Shuttle gefunden, speichere Achse
				slaveAxis := FB_ppGet.Axis;
				// Aktiviere lesen des Slave Position
				FB_readSetSlave.Axis := ADR(slaveAxis);
				FB_readSetSlave.Enable := TRUE;
				FB_readActSlave.Axis := ADR(slaveAxis);
				FB_readActSlave.Enable := TRUE;
				// Weiter
				fsmStep := STEP_GET_SLAVE;
			END_IF;
		
		STEP_GET_SLAVE:
			// Löse ein Shuttle aus dem Depot
			FB_ppCommand.AdvancedParameters.TicketCount := 1;
			FB_ppCommand.Command := mcACPTRAK_BARRIER_ADD_TICKETS;
			FB_ppCommand.Execute := TRUE;
			// Weiter wenn Kommando ausgeführt wurde
			IF FB_ppCommand.Done THEN
				FB_ppCommand.Execute := FALSE;
				fsmStep := STEP_POS_SLAVE;
			END_IF;
		
		STEP_POS_SLAVE:
			// Sende neue Sollposition
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := trakConvoy.startPos - trakConvoy.coupleDistance - 0.01;
			FB_move.Axis := ADR(slaveAxis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				fsmStep := STEP_PREPARED;
			END_IF;
		
		STEP_PREPARED:
			// Warte auf Ready + Befehl.
			IF (trakConvoy.cmd.couple AND trakAsmb.state.ready) THEN
				trakConvoy.cmd.couple := FALSE;
				fsmStep := STEP_CONVOY_CREATE;
			END_IF;
		
		STEP_CONVOY_CREATE:
			// Erstelle Convoy
			FB_createConvoy.Axis := ADR(masterAxis);
			FB_createConvoy.Execute := TRUE;
			// Weiter wenn Convoy erstellt wurde
			IF FB_createConvoy.Done THEN
				FB_createConvoy.Execute := FALSE;
				fsmStep := STEP_CONVOY_ADD;
			END_IF;
			
		STEP_CONVOY_ADD:
			// Slave dem Convoy hinzufügen
			FB_add2Convoy.Parameters.ReferenceShuttle := ADR(masterAxis); // master
			FB_add2Convoy.Axis := ADR(slaveAxis); // slave
			FB_add2Convoy.Execute := TRUE;
			// Weiter wenn an Convoy angeschlossen
			IF FB_add2Convoy.Done THEN
				FB_add2Convoy.Execute := FALSE;
				fsmStep := STEP_CONVOY_COUPLE;
			END_IF;
		
		STEP_CONVOY_COUPLE:
			// Pseudo koppeln. Durch Convoy sind Shuttles bereits gekoppelt aber Convoy wurde erst gerade erstellt.
			// Mit einem Move Befehl den Master auf der aktuellen Position (+kleiner Offset) neu positionieren, dies
			// sollte gesamtes Convoy neu ausrichten bez. die eingestellten Abstände einstellen.
			// Sende neue Sollposition
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := trakConvoy.startPos + 0.01;
			FB_move.Axis := ADR(masterAxis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				fsmStep := STEP_COUPLED;
			END_IF;
		
		STEP_COUPLED:
			// Warte auf Ready + Befehl.
			IF (trakConvoy.cmd.move AND trakAsmb.state.ready) THEN
				trakConvoy.cmd.move := FALSE;
				fsmStep := STEP_MOVE;
			END_IF;
		
		STEP_MOVE:
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := trakConvoy.targetPos;
			FB_move.Axis := ADR(masterAxis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				fsmStep := STEP_MOVED;
			END_IF;
		
		STEP_MOVED:
			// Warte auf Ready + Befehl.
			IF (trakConvoy.cmd.release AND trakAsmb.state.ready) THEN
				trakConvoy.cmd.release := FALSE;
				fsmStep := STEP_RELEASE_SLAVE;
			END_IF;
		
		STEP_RELEASE_SLAVE:
			// Entferne Slave aus dem Convoy mittels Bewegungsbefehl.
			FB_move.Sector := ADR(gSecFull);
			FB_move.Position := trakConvoy.targetPos - trakConvoy.coupleDistance - 0.01;
			FB_move.AdvancedParameters.EndDirection := mcDIR_NEGATIVE; // fahre rückwärts!
			FB_move.Axis := ADR(slaveAxis);
			FB_move.Execute := TRUE;
			// Weiter wenn Bewegung abgeschlossen.
			IF FB_move.Done THEN
				FB_move.Execute := FALSE;
				FB_move.AdvancedParameters.EndDirection := mcDIR_POSITIVE;
				fsmStep := STEP_RELEASE_MASTER;
			END_IF;
		
		STEP_RELEASE_MASTER:
			// Löse Convoy auf.
			FB_deleteConvoy.ConvoyMaster := ADR(masterAxis);
			FB_deleteConvoy.Execute := TRUE;
			// Weiter wenn Convoy aufgelöst.
			IF FB_deleteConvoy.Done THEN
				FB_deleteConvoy.Execute := FALSE;
				fsmStep := STEP_RELEASED;
			END_IF;
		
		STEP_RELEASED:
			// Warte auf Ready + Befehl.
			IF (trakConvoy.cmd.return AND trakAsmb.state.ready) THEN
				trakConvoy.cmd.return := FALSE;
				fsmStep := STEP_RETURN_MASTER;
			END_IF;
		
		STEP_RETURN_MASTER:
			FB_moveVel.Sector := ADR(gSecFull);
			FB_moveVel.Position := 6.0; // Position ist hinterhalb des PP gPPDepot (ist bei pos 5.6)
			FB_moveVel.Axis := ADR(masterAxis);
			FB_moveVel.Execute := TRUE;
			// Direkt weiter.
			fsmStep := STEP_RETURN_MASTER_WAIT;
			
		STEP_RETURN_MASTER_WAIT:
			// Direkt weiter sobald Fahrbefehl aktiv, wird im Hintergrund weitergeführt.
			IF FB_moveVel.Active THEN
				FB_moveVel.Execute := FALSE;
				fsmStep := STEP_RETURN_SLAVE;
			END_IF;
		
		STEP_RETURN_SLAVE:
			FB_moveVel.Sector := ADR(gSecFull);
			FB_moveVel.Position := 6.0; // Position ist hinterhalb des PP gPPDepot (ist bei pos 5.6)
			FB_moveVel.Axis := ADR(slaveAxis);
			FB_moveVel.Execute := TRUE;
			// Direkt weiter.
			fsmStep := STEP_RETURN_SLAVE_WAIT;
			
		STEP_RETURN_SLAVE_WAIT:
			// Direkt weiter sobald Fahrbefehl aktiv, wird im Hintergrund weitergeführt.
			IF FB_moveVel.Active THEN
				FB_moveVel.Execute := FALSE;
				fsmStep := STEP_RETURNED;
			END_IF;
		
		STEP_RETURNED:
			// Dummy step, gehe zurück in Start. Shuttles sind ggf. noch unterwegs ins Depot.
			fsmStep := STEP_IDLE;
		
			
	END_CASE;
	
	// Status zurückmelden
	trakConvoy.state.prepared := (fsmStep = STEP_PREPARED);
	trakConvoy.state.coupled  := (fsmStep = STEP_COUPLED);
	trakConvoy.state.moved    := (fsmStep = STEP_MOVED);
	trakConvoy.state.released := (fsmStep = STEP_RELEASED);
	trakConvoy.state.returned := (fsmStep = STEP_RETURNED OR fsmStep = STEP_IDLE);
	
	// Alle Bewegungs-FBs deaktivieren wenn Assembly nicht ready ist.
	IF NOT trakAsmb.state.ready THEN
		FB_move.Execute := FALSE;
		FB_moveVel.Execute := FALSE;
	END_IF;
	
	// Bei Reset Kommando alle Bewegungs-FBs deaktivieren und Zustand wechseln.
	IF trakConvoy.cmd.reset THEN
		FB_move.Execute := FALSE;
		FB_moveVel.Execute := FALSE;
		trakConvoy.cmd.reset := FALSE;
		fsmStep := STEP_RESET;
	END_IF;
	
	// Rufe alle FBs zyklisch auf, werden aber nur berechnet wenn "Enable" oder "Execute" aktiv.
	FB_move();
	FB_moveVel();
	FB_createConvoy();
	FB_add2Convoy();
	FB_deleteConvoy();
	FB_readSetMaster();
	FB_readActMaster();
	FB_readSetSlave();
	FB_readActSlave();
	FB_ppCommand();
	FB_ppGet();
	
	distanceActual := FB_readActMaster.CyclicPosition - FB_readActSlave.CyclicPosition;
	distanceSet := FB_readSetMaster.CyclicPosition - FB_readSetSlave.CyclicPosition;
	
	// Enable der FBs deaktivieren wenn Busy Signal geht oder Fehler ansteht.
	//IF EDGENEG(FB_move.Busy) OR FB_move.Error THEN
	//	FB_move.Execute := FALSE;
	//END_IF;
	//IF EDGENEG(FB_couple.Busy) OR FB_couple.Error THEN
	//	FB_couple.Execute := FALSE;
	//END_IF;
	 
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

