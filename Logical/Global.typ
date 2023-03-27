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
END_TYPE
