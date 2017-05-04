public void SpecialDays_Init_Freeday()
{
  SpecialDays_RegisterDay("Freeday", SpecialDays_Freeday_Start, SpecialDays_Freeday_End, SpecialDays_Freeday_RestrictionCheck, SpecialDays_Freeday_OnClientPutInServer, true, false);
}

public void SpecialDays_Freeday_Start() 
{
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Freeday");
}

public void SpecialDays_Freeday_End() 
{
  //Nop
}

public bool SpecialDays_Freeday_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void SpecialDays_Freeday_OnClientPutInServer() 
{
  //Nop
}
