/*
* Mic Check Feature
* Prefix: miccheck_
*/

#if defined _wardentools_miccheck_included
  #endinput
#endif
#define _wardentools_miccheck_included

#include <wardentools>
#include "voiceannounce_ex.inc"

//Convar
ConVar cvar_miccheck_time = null;

//Global statics
static ArrayList micSwapTargets;
static bool micCheckConducted = false;
static bool isInMicCheckTime = false;

//OnPluginStart
public void Miccheck_OnPluginStart()
{
  cvar_miccheck_time = CreateConVar("sm_wardentools_miccheck_time", "15.0", "The amount of time guards have to use their mic in a mic check (def. 15.0)");
  
  RegAdminCmd("sm_miccheck", Miccheck_PerformCommand, ADMFLAG_GENERIC, "Conduct a mic check");
  RegAdminCmd("sm_mc", Miccheck_PerformCommand, ADMFLAG_GENERIC, "Conduct a mic check");
  
  HookEvent("round_prestart", Miccheck_Reset, EventHookMode_Post);
  
  //Create array
  micSwapTargets = CreateArray();
}

//Round pre start
public void Miccheck_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  micCheckConducted = false;
  isInMicCheckTime = false;
  ClearArray(micSwapTargets);
}

//Perform Mic check
public Action Miccheck_PerformCommand(int client, int args) {
  if (isInMicCheckTime) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck Already Happening");
    return Plugin_Handled;
  }
  else if (micCheckConducted) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck Already Conducted");
    return Plugin_Handled;
  }
  
  //Say who started a mic check
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Miccheck Started All", client);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_CT) {
        //Perform Mic Check
        CPrintToChat(i, "%s%t", CHAT_TAG_PREFIX, "Miccheck Started CT", client, RoundToNearest(GetConVarFloat(cvar_miccheck_time)));
        PrintHintText(i, "%t", "Miccheck Status Not Verified");
        PushArrayCell(micSwapTargets, i);
        CreateTimer(0.5, Miccheck_MicCheck, i);
      }
    }
  }
  
  isInMicCheckTime = true;
  micCheckConducted = true;
  
  //Create timer to stop mic check
  CreateTimer(GetConVarFloat(cvar_miccheck_time), Miccheck_MicCheckFinish);

  return Plugin_Handled;
}

//Check gaurd mic
public Action Miccheck_MicCheck(Handle timer, int client)
{
  if (!isInMicCheckTime)
    return Plugin_Handled;
  
  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    if (GetClientTeam(client) == CS_TEAM_CT) {
      if (IsClientSpeaking(client)) {
        PrintHintText(client, "%t", "Miccheck Status Verified");
        RemoveFromArray(micSwapTargets, FindValueInArray(micSwapTargets, client)); //remove this verified client from the array
      } else {
        PrintHintText(client, "%t", "Miccheck Status Not Verified");
        CreateTimer(0.5, Miccheck_MicCheck, client);
      }
    }
  }

  return Plugin_Handled;
}

//Finish MicCheck
public Action Miccheck_MicCheckFinish(Handle timer)
{
  isInMicCheckTime = false;
  int numGuardsMoved = 0;
  
  for (int i = 0; i < GetArraySize(micSwapTargets); ++i) {
    int client = GetArrayCell(micSwapTargets, i);
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
  
  ClearArray(micSwapTargets);
}

//Getters/setters
public bool Miccheck_IsMicCheckConducted()
{
  return micCheckConducted;
}