
PROGRAM _INIT
	// Initialsiere alle FBs
	FB_status.Assembly := ADR(gAssemblyFigure8);
	FB_reset.Assembly := ADR(gAssemblyFigure8);
	FB_powerOff.Assembly := ADR(gAssemblyFigure8);
	FB_powerOn.Assembly := ADR(gAssemblyFigure8);
	FB_getShuttle.Assembly := ADR(gAssemblyFigure8);
	FB_addShuttle.Sector := ADR(gSecMinor);
	FB_addShuttle.Sector := ADR(gDummyAxis);
	FB_addShuttle.Sector := ADR(gSecMajor);
	FB_addShuttle.Sector := ADR(gSecFull);
	
	// alle FBs ausser status deaktivieren
	FB_reset.Execute := FALSE;
	FB_powerOff.Execute := FALSE;
	FB_powerOn.Execute := FALSE;
	FB_getShuttle.Enable := FALSE;
	
	// Status FB aktivieren
	FB_status.Enable := TRUE;
	
	// Shuttle-Get FSM auf Reset
	getShuttleStep := getShuttleRESET;
	simShuttleCount := 0;
	 
END_PROGRAM

PROGRAM _CYCLIC
	// Was ist der Zustand des Assembly?
	trakAsmb.state.errorStop := FB_status.AssemblyErrorStop;
	trakAsmb.state.disabled := FB_status.AssemblyDisabled;
	trakAsmb.state.homing := FB_status.AssemblyHoming;
	trakAsmb.state.stopping := FB_status.AssemblyStopping;
	// Wir sind die Shuttles am laden wenn Assembly bereit, aber Shuttle-Get FSM noch nicht.
	trakAsmb.state.loading := FB_status.AssemblyReady AND (getShuttleStep <> getShuttleDONE) AND getShuttleStep > getShuttleWAIT;
	// Wir sind komplett Bereit wenn Assembly und Shuttle-Get FSM bereit.
	trakAsmb.state.ready := FB_status.AssemblyReady AND getShuttleStep = getShuttleDONE;
	
	// Einschaltbefehl zurücksetzen wenn Zustand Ready verlassen wird.
	IF EDGENEG(FB_status.AssemblyReady) THEN
		trakAsmb.cmd.power := FALSE;
	END_IF;
	
	// Sind wir im Error oder wollen wir manuell Zurücksetzen? => Assembly zurücksetzen
	IF trakAsmb.state.errorStop OR trakAsmb.cmd.reset THEN
		FB_reset.Execute := TRUE;
		getShuttleStep := getShuttleRESET;
		trakAsmb.cmd.power := FALSE;
	END_IF;
	
	// Nach Reset kommen wir in Disabled, mit Einschaltbefehl ein PowerOn durchführen.
	IF trakAsmb.state.disabled AND trakAsmb.cmd.power THEN
		FB_powerOn.Execute := TRUE;
	END_IF;
	
	// Sind wir in Homing/Loading/Ready aber ohne Einschaltbefehl? => Stoppe Assembly
	IF (trakAsmb.state.homing OR trakAsmb.state.loading OR trakAsmb.state.ready) AND NOT trakAsmb.cmd.power THEN
		FB_powerOff.Execute := TRUE;
	END_IF;
	
	// Befehl zum Neuladen der Shuttles erhalten? => Get-Shuttle FSM zurücksetzen.
	IF (trakAsmb.cmd.reload AND getShuttleStep = getShuttleDONE) THEN
		getShuttleStep := getShuttleRESET;
		trakAsmb.cmd.reload := FALSE;
	END_IF;
	
	// Durchlaufe eine FSM um die Shuttlereferenzen per getShuttle FB zu erhalten.
	CASE getShuttleStep OF
		getShuttleRESET:
			// lösche die komplette Referenzstruktur
			brsmemset(ADR(trakAsmb.shuttles), 0, SIZEOF(trakAsmb.shuttles));
			trakAsmb.shuttleCount := 0;
			// warte auf nächsten Wechsel in Ready
			getShuttleStep := getShuttleWAIT;
			
		getShuttleWAIT:
			// Warte bis Assembly in Zustand Ready übergeht.
			IF FB_status.AssemblyReady THEN
				//getShuttleStep := getShuttleLOADWAIT;
				getShuttleStep := getShuttleADDWAIT;
			END_IF;
			
		getShuttleADDWAIT:
			trakAsmb.shuttleCount := 2;
			// Füge ein Shuttle hinzu (nur Simulation!), trakAsmb.shuttleCount dient als Anzahl der Shuttles.
			FB_addShuttle.Position := simShuttleCount * 0.1;
			FB_addShuttle.Execute := TRUE;
			IF FB_addShuttle.Done THEN
				FB_addShuttle.Execute := FALSE;
				getShuttleStep := getShuttleADD;
			END_IF;
			
		getShuttleADD:
			// Zähle hoch und falls geforderte Anzahl erreicht, gehe weiter.
			simShuttleCount := simShuttleCount + 1;
			IF simShuttleCount = trakAsmb.shuttleCount THEN
				getShuttleStep := getShuttleLOADWAIT;
			ELSE
				getShuttleStep := getShuttleADDWAIT;
			END_IF;
		
		getShuttleLOADWAIT:
			// Rufe GetShuttle FB auf und warte bis dieser fertig ist.
			FB_getShuttle.Enable := TRUE;
			FB_getShuttle.Next := TRUE;
			IF FB_getShuttle.Valid THEN
				getShuttleStep := getShuttleLOAD;
			END_IF;
			
		getShuttleLOAD:
			// Speichere Daten des geladenen Shuttles.
			trakAsmb.shuttles[FB_getShuttle.RemainingCount].axis := FB_getShuttle.Axis;
			trakAsmb.shuttles[FB_getShuttle.RemainingCount].id := FB_getShuttle.AdditionalInfo.ShuttleID;
			// Haben wir alle Shuttles gelesen?
			IF FB_getShuttle.RemainingCount <> 0 THEN
				// Nein, setze Next zurück, nächstes Laden eines Shuttles wird mit positiver Flanke im LOADWAIT ausgelöst.
				FB_getShuttle.Next := FALSE;
				getShuttleStep := getShuttleLOADWAIT;
			ELSE
				// Ja, wir sind fertig.
				getShuttleStep := getShuttleDONE;
				// speichere zudem die Anzahl gefundener Shuttles
				trakAsmb.shuttleCount := FB_getShuttle.TotalCount;
			END_IF;
				
		getShuttleDONE:
			// Alle Shuttles geladen, deaktiviere FB wir sind fertig.
			FB_getShuttle.Enable := FALSE;
			FB_getShuttle.Next := FALSE;
			// Lösche Befehl zum neuladen.
			trakAsmb.cmd.reload := FALSE;

	END_CASE;
	
	
	
	// Rufe alle FBs zyklisch auf, werden aber nur berechnet wenn "Enable" oder "Execute" aktiv.
	FB_status();
	FB_reset();
	FB_powerOff();
	FB_powerOn();
	FB_getShuttle();
	FB_addShuttle();
	
	// Enable der FBs deaktivieren wenn Busy Signal geht oder Fehler ansteht.
	IF EDGENEG(FB_reset.Busy) OR FB_reset.Error THEN
		FB_reset.Execute := FALSE;
		trakAsmb.cmd.reset := FALSE;
	END_IF;
	IF EDGENEG(FB_powerOff.Busy) OR FB_powerOff.Error THEN
		FB_powerOff.Execute := FALSE;
	END_IF;
	IF EDGENEG(FB_powerOn.Busy) OR FB_powerOn.Error THEN
		FB_powerOn.Execute := FALSE;
	END_IF;
	 
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

