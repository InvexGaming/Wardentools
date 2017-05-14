/*
* Mic Check Feature
* Prefix: MicCheck_
*/

#if defined _wardentools_miccheck_included
  #endinput
#endif
#define _wardentools_miccheck_included

#include <wardentools>
#include "voiceannounce_ex.inc"

//Convar
ConVar g_Cvar_MicCheck_Time = null;

//Global statics
static ArrayList s_MicSwapTargets;
static bool s_MicCheckConducted = false;
static bool s_IsInMicCheckTime = false;

//OnPluginStart
public void MicCheck_OnPluginStart()
{
  g_Cvar_MicCheck_Time = CreateConVar("sm_wt_MicCheck_time", "15.0", "The amount of time guards have to use their mic in a mic check (def. 15.0)");
  
  RegAdminCmd("sm_miccheck", MicCheck_PerformCommand, ADMFLAG_GENERIC, "Conduct a mic check");
  RegAdminCmd("sm_mc", MicCheck_PerformCommand, ADMFLAG_GENERIC, "Conduct a mic check");
  
  HookEvent("round_prestart", MicCheck_Reset, EventHookMode_Post);
  
  //Create array
  s_MicSwapTargets = new ArrayList();
}

//Round pre start
public void MicCheck_Reset(Event event, const char[] name, bool dontBroadcast)
{
  s_MicCheckConducted = false;
  s_IsInMicCheckTime = false;
  s_MicSwapTargets.Clear();
}

//Perform Mic check
public Action MicCheck_PerformCommand(int client, int args) {
  if (s_IsInMicCheckTime) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck Already Happening");
    return Plugin_Handled;
  }
  else if (s_MicCheckConducted) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck Already Conducted");
    return Plugin_Handled;
  }
  
  //Say who started a mic check
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Miccheck Started All", client);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_CT) {
        //Perform Mic Check
        CPrintToChat(i, "%s%t", CHAT_TAG_PREFIX, "Miccheck Started CT", client, RoundToNearest(g_Cvar_MicCheck_Time.FloatValue));
        PrintHintText(i, "%t", "Miccheck Status Not Verified");
        s_MicSwapTargets.Push(i);
        CreateTimer(0.5, MicCheck_MicCheck, i);
      }
    }
  }
  
  s_IsInMicCheckTime = true;
  s_MicCheckConducted = true;
  
  //Create timer to stop mic check
  CreateTimer(g_Cvar_MicCheck_Time.FloatValue, MicCheck_MicCheckFinish);
  
  return Plugin_Handled;
}

//Check gaurd mic
public Action MicCheck_MicCheck(Handle timer, int client)
{
  if (!s_IsInMicCheckTime)
    return Plugin_Handled;
  
  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    if (GetClientTeam(client) == CS_TEAM_CT) {
      if (IsClientSpeaking(client)) {
        PrintHintText(client, "%t", "Miccheck Status Verified");
        s_MicSwapTargets.Erase(s_MicSwapTargets.FindValue(client)); //remove this verified client from the array
      } else {
        PrintHintText(client, "%t", "Miccheck Status Not Verified");
        CreateTimer(0.5, MicCheck_MicCheck, client);
      }
    }
  }
  
  return Plugin_Handled;
}

//Finish MicCheck
public Action MicCheck_MicCheckFinish(Handle timer)
{
  s_IsInMicCheckTime = false;
  int numGuardsMoved = 0;
  
  for (int i = 0; i < s_MicSwapTargets.Length; ++i) {
    int client = s_MicSwapTargets.Get(i);
    if (IsClientInGame(client)) {
      if (GetClientTeam(client) == CS_TEAM_CT) {
        //Swap clients team
        ChangeClientTeam(client, CS_TEAM_T);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck You Were Swapped");
        ++numGuardsMoved;
      }
    }
  }
  
  //Miccheck finished
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Miccheck Finished", numGuardsMoved);
  
  s_MicSwapTargets.Clear();
}

//Getters/setters
public bool MicCheck_IsMicCheckConducted()
{
  return s_MicCheckConducted;
}