public void Specialdays_Init_Freeday()
{
  Specialdays_RegisterDay("Freeday", Specialdays_Freeday_Start, Specialdays_Freeday_End, Specialdays_Freeday_RestrictionCheck, Specialdays_Freeday_OnClientPutInServer, true, false);
}

public void Specialdays_Freeday_Start() 
{
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Freeday");
}

public void Specialdays_Freeday_End() 
{
  //Nop
}

public bool Specialdays_Freeday_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void Specialdays_Freeday_OnClientPutInServer() 
{
  //Nop
}
