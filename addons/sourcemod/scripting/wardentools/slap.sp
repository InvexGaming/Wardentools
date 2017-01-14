/*
* Slap game mode
* Prefix: slap_
*/

#if defined _wardentools_slap_included
  #endinput
#endif
#define _wardentools_slap_included

#include <wardentools>
#include <sdktools>
#include <cstrike>

public void Slap_SlapPrisoners()
{
  //Slap Prisoners
  for (int i = 1; i <= MaxClients ; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        SlapPlayer(i, 0, true);
      }
    }
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Slap");
}