public void SpecialDays_Init_CustomDay()
{
  SpecialDays_RegisterDay("Custom Special Day", SpecialDays_CustomDay_Start, SpecialDays_CustomDay_End, SpecialDays_CustomDay_RestrictionCheck, SpecialDays_CustomDay_OnClientPutInServer, true, false);
}

public void SpecialDays_CustomDay_Start() 
{
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Custom");
}

public void SpecialDays_CustomDay_End() 
{
  //Nop
}

public bool SpecialDays_CustomDay_RestrictionCheck(int client) 
{
  //Passed with no failures
  return true;
}

public void SpecialDays_CustomDay_OnClientPutInServer() 
{
  //Nop
}