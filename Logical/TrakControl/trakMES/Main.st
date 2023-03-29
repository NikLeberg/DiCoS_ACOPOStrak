
PROGRAM _INIT
	// Initial alle MES Kommandos deaktivieren
	trakMES.cmd.goABB := FALSE;
	trakMES.cmd.goDelta := FALSE;
	 
END_PROGRAM

PROGRAM _CYCLIC
	// Status aus den verschiedenen Programmen zusammentragen
	trakMES.state.power := trakAsmb.state.ready;
	trakMES.state.atABB := trakSingle.state.atABB;
	trakMES.state.atDelta := trakSingle.state.atDelta;
	
	// Kommandos den verschiedenen Programmen übergeben
	trakSingle.cmd.goABB := trakMES.cmd.goABB;
	trakSingle.cmd.goDelta := trakMES.cmd.goDelta;
	IF EDGEPOS(trakSingle.state.moving) THEN
		trakMES.cmd.goABB := FALSE;
		trakMES.cmd.goDelta := FALSE;
	END_IF;
	
	
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

