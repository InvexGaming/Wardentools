//Convars
ConVar g_Cvar_SpecialDays_WarDay_TeleportTime = null;

public void SpecialDays_Init_WarDay()
{
  SpecialDays_RegisterDay("Warday", SpecialDays_WarDay_Start, SpecialDays_WarDay_End, SpecialDays_WarDay_RestrictionCheck, SpecialDays_WarDay_OnClientPutInServer, false, false);
  
  g_Cvar_SpecialDays_WarDay_TeleportTime = CreateConVar("sm_wt_specialdays_warday_tptime", "30.0", "The amount of time before prisoners are teleported to start beacon (def. 30.0)");
}

public void SpecialDays_WarDay_Start() 
{
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Warday", RoundToNearest(g_Cvar_SpecialDays_WarDay_TeleportTime.FloatValue));
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, g_Cvar_SpecialDays_WarDay_TeleportTime.FloatValue);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_WarDay_TeleportTime.FloatValue, "warday", SpecialDays_Teleport_Start_T, TeleportType_T);
}

public void SpecialDays_WarDay_End() 
{
  //nop
}

public bool SpecialDays_WarDay_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void SpecialDays_WarDay_OnClientPutInServer() 
{
  //Nop
}