public void Specialdays_Init_CustomDay()
{
  Specialdays_RegisterDay("Custom Special Day", Specialdays_CustomDay_Start, Specialdays_CustomDay_End, Specialdays_CustomDay_RestrictionCheck, Specialdays_CustomDay_OnClientPutInServer, true, false);
}

public void Specialdays_CustomDay_Start() 
{
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Custom");
}

public void Specialdays_CustomDay_End() 
{
  //Nop
}

public bool Specialdays_CustomDay_RestrictionCheck(int client) 
{
  //Passed with no failures
  return true;
}

public void Specialdays_CustomDay_OnClientPutInServer() 
{
  //Nop
}