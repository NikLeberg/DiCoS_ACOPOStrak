
TYPE
	trakMoveCmd_t : 	STRUCT 
		trace : BOOL;
		test : BOOL;
	END_STRUCT;
	trakMove_t : 	STRUCT 
		cmd : trakMoveCmd_t;
	END_STRUCT;
	intCoupleStep_t : 
		(
		coupleStepWAIT,
		coupleStepSENDPOS1,
		coupleStepSENDPOS2,
		coupleStepSETOBJ1,
		coupleStepSETOBJ2,
		coupleStepCOUPLE,
		coupleStepDONE
	);
END_TYPE
