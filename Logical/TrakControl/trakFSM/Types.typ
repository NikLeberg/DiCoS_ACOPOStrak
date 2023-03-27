
TYPE
	intGetShuttleStep_t : 
		( (*Interner Schrittzustand des Shuttle-Get Befehls*)
		getShuttleRESET, (*Reset des trakShuttle Array Struktur*)
		getShuttleWAIT, (*Warte auf Ready des Assembly*)
		getShuttleADDWAIT, (*Simulation: Füge Shuttles hinzu*)
		getShuttleADD,
		getShuttleLOADWAIT, (*Triggere das Laden eines Shuttles*)
		getShuttleLOAD, (*Shuttle geladen, speichere seine Referenz*)
		getShuttleDONE (*Alle Shuttle Referenzen gespeichert, fertig.*)
		);
END_TYPE
