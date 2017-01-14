/*
* Manipulate player health (HP)
* Prefix: sethealth_
*/

#if defined _wardentools_sethealth_included
  #endinput
#endif
#define _wardentools_sethealth_included

#include <wardentools>
#include <cstrike>

public void Sethealth_ResetTHealth()
{
  //Show message to server
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gametools - Set T Health", 100);

  for (int i = 1; i <= MaxClients ; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        SetEntProp(i, Prop_Data, "m_iHealth", 100);
      }
    }
  }
}