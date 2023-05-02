(*OPC UA Interface*)

TYPE
	trakMes_t : 	STRUCT 
		cmd : trakMesCmd_t; (*Kommandos MES -> trak*)
		state : trakMesState_t; (*Status trak -> MES*)
	END_STRUCT;
	trakMesCmd_t : 	STRUCT 
		goABB : BOOL; (*Setzen durch MES, Rücksetzen durch trak FSM als Kommando Bestätigung*)
		goDelta : BOOL; (*Setzen durch MES, Rücksetzen durch trak FSM als Kommando Bestätigung*)
	END_STRUCT;
	trakMesState_t : 	STRUCT 
		power : BOOL; (*trak Assembly ist On*)
		atABB : BOOL; (*Shuttle beim ABB Roboter*)
		atDelta : BOOL; (*Shuttle beim Delta Roboter*)
	END_STRUCT;
END_TYPE

(*Assembly Interface*)

TYPE
	trakState_t : 	STRUCT 
		ready : BOOL;
		loading : BOOL; (*Führe Get-Shuttle FSM aus, Assembly bereit aber Shuttle Referenzen noch nicht*)
		homing : BOOL;
		stopping : BOOL;
		disabled : BOOL;
		errorStop : BOOL;
	END_STRUCT;
	trakAsmbCmd_t : 	STRUCT 
		simulation : USINT; (*Wenn >0, dann ist Simulationsmodus aktiv bez. diese Anzahl an Shuttles wird simuliert*)
		reload : BOOL; (*Neuladen aller Shuttles*)
		reset : {REDUND_UNREPLICABLE} BOOL; (*Beim setzen auf 1 wird Asmb zurückgesetzt.*)
		power : BOOL; (*Beim setzen auf 1 wird automatisch Asmb FSM bis auf Zustand Ready gebracht.*)
	END_STRUCT;
	trakShuttle_t : 	STRUCT 
		id : UINT;
		axis : McAxisType;
	END_STRUCT;
	trakAsmb_t : 	STRUCT 
		monData : McAcpTrakAssemblyMonData;
		shuttleCount : UINT; (*Anzahl gefundener Shuttles*)
		shuttles : ARRAY[0..9]OF trakShuttle_t; (*Referenzen auf Shuttle Achsen & IDs*)
		state : trakState_t;
		cmd : trakAsmbCmd_t;
	END_STRUCT;
	New_Datatype : 	STRUCT 
	END_STRUCT;
END_TYPE

(*Single Interface*)

TYPE
	trakSingleCmd_t : 	STRUCT 
		goABB : BOOL;
		goDelta : BOOL;
		read : BOOL;
	END_STRUCT;
	trakSingleState_t : 	STRUCT 
		moving : BOOL;
		atABB : BOOL;
		atDelta : BOOL;
	END_STRUCT;
	trakSingle_t : 	STRUCT 
		cmd : trakSingleCmd_t;
		state : trakSingleState_t;
	END_STRUCT;
END_TYPE

(*Convoy Interface*)

TYPE
	trakConvoyCmd_t : 	STRUCT 
		reset : BOOL;
		prepare : BOOL;
		couple : BOOL;
		move : BOOL;
		release : BOOL;
		return : BOOL;
	END_STRUCT;
	trakConvoyState_t : 	STRUCT 
		prepared : BOOL;
		coupled : BOOL;
		moved : BOOL;
		released : BOOL;
		returned : BOOL;
	END_STRUCT;
	trakConvoy_t : 	STRUCT 
		state : trakConvoyState_t;
		cmd : trakConvoyCmd_t;
		startPos : LREAL;
		coupleDistance : LREAL;
		targetPos : LREAL;
	END_STRUCT;
END_TYPE
