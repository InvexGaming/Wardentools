/*
* Freezebomb game
* Prefix: FreezeBomb_
*/

#if defined _wardentools_freezebomb_included
  #endinput
#endif
#define _wardentools_freezebomb_included

#include <wardentools>

//Static globals
static bool s_ShouldFreezeT = false;
static Handle s_FreezeTimer = null;

//OnPluginStart
public void FreezeBomb_OnPluginStart()
{
  HookEvent("round_prestart", FreezeBomb_Reset, EventHookMode_Post);
}

public void FreezeBomb_ToggleFreezeBomb()
{
  //Freezebomb Prisoners
  s_ShouldFreezeT = !s_ShouldFreezeT;
  ServerCommand("sm_freezebomb @t"); //Toggle freezebomb status
  
  if (s_ShouldFreezeT == false) {
    //We stopped an already running timer
    delete s_FreezeTimer;
    
    //Reenable unlockables
    ToggleUnlockables(CS_TEAM_T, 1);
  }
  else {
    //Disable unlockables
    ToggleUnlockables(CS_TEAM_T, 0);
    s_FreezeTimer = CreateTimer(FindConVar("sm_freeze_duration").FloatValue + 0.5, FreezeBomb_ReportFreezebombResults);
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Freezebomb");
}

//Report Freezebomb results
public Action FreezeBomb_ReportFreezebombResults(Handle timer)
{
  s_FreezeTimer = null;
  
  //Check to see if timer should be stopped
  if (!s_ShouldFreezeT) {
    return Plugin_Handled;
  }
  
  //Reenable unlockables
  ToggleUnlockables(CS_TEAM_T, 1);
  
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
  s_ShouldFreezeT = false;
  
  return Plugin_Handled;
}

//Round pre start
public void FreezeBomb_Reset(Event event, const char[] name, bool dontBroadcast)
{
  s_ShouldFreezeT = false;
  s_FreezeTimer = null;
}
