//Convars
ConVar cvar_specialdays_warday_tptime = null;

public void Specialdays_Init_Warday()
{
  Specialdays_RegisterDay("Warday", Specialdays_Warday_Start, Specialdays_Warday_End, Specialdays_Warday_RestrictionCheck, Specialdays_Warday_OnClientPutInServer, false, false);
  
  cvar_specialdays_warday_tptime = CreateConVar("sm_wt_specialdays_warday_tptime", "30.0", "The amount of time before prisoners are teleported to start beacon (def. 30.0)");
}

public void Specialdays_Warday_Start() 
{
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Warday", RoundToNearest(GetConVarFloat(cvar_specialdays_warday_tptime)));
  
  //Create timer for damage protection
  Specialdays_SetDamageProtection(true, GetConVarFloat(cvar_specialdays_warday_tptime));
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_warday_tptime), "warday", Specialdays_Teleport_Start_T, TELEPORTTYPE_T);
}

public void Specialdays_Warday_End() 
{
  //nop
}

public bool Specialdays_Warday_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void Specialdays_Warday_OnClientPutInServer() 
{
  //Nop
}