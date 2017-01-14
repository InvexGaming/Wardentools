/*
* Freezebomb game
* Prefix: freezebomb_
*/

#if defined _wardentools_freezebomb_included
  #endinput
#endif
#define _wardentools_freezebomb_included


#include <wardentools>

//Static globals
static bool shouldFreezeT = false;
static Handle freezeTimer = null;

//OnPluginStart
public void Freezebomb_OnPluginStart()
{
  HookEvent("round_prestart", Freezebomb_Reset, EventHookMode_Post);
}

public void Freezebomb_ToggleFreezeBomb()
{
  //Freezebomb Prisoners
  shouldFreezeT = !shouldFreezeT;
  ServerCommand("sm_freezebomb @t"); //Toggle freezebomb status
  
  if (shouldFreezeT == false) {
    //We stopped an already running timer
    if (freezeTimer != null) {
      KillTimer(freezeTimer);
      freezeTimer = null;
    }
    
    //Reenable unlockables
    toggleUnlockables(CS_TEAM_T, 1);
  }
  else {
    //Disable unlockables
    toggleUnlockables(CS_TEAM_T, 0);
    freezeTimer = CreateTimer(GetConVarFloat(FindConVar("sm_freeze_duration")) + 0.5, Freezebomb_ReportFreezebombResults);
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Freezebomb");
}

//Report Freezebomb results
public Action Freezebomb_ReportFreezebombResults(Handle timer)
{
  //Check to see if timer should be stopped
  if (!shouldFreezeT) {
    return Plugin_Handled;
  }
  
  //Reenable unlockables
  toggleUnlockables(CS_TEAM_T, 1);
  
  //Report results
  int highestClient = -1;
  int lowestClient = -1;
  float highestCord = -999999.0;
  float lowestCord = 999999.0;
      
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        float player_vec[3];
        GetClientAbsOrigin(i, player_vec);
        
        if (player_vec[2] > highestCord) {
          highestCord = player_vec[2];
          highestClient = i;
        }
        
        if (player_vec[2] < lowestCord) {
          lowestCord = player_vec[2];
          lowestClient = i;
        }
        
      }
    }
  }

  if (highestClient != -1) 
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Highest Freezebomb", highestClient);
  
  if (lowestClient != -1)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Lowest Freezebomb", lowestClient);
  
  //Disable freeze bool
  shouldFreezeT = false;
  
  return Plugin_Handled;
}

//Round pre start
public void Freezebomb_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  shouldFreezeT = false;
  freezeTimer = null;
}
