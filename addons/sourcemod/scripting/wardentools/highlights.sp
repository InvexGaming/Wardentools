/*
* Highlight players with various colours that can be used by other modules
* Prefix: Highlights_
*/

#if defined _wardentools_highlights_included
  #endinput
#endif
#define _wardentools_highlights_included

#include <wardentools>
#include "wardentools/colours.sp"

//Static Globals
static bool s_IsHighlighted[MAXPLAYERS+1] = false;
static Colour s_HighlightedColour[MAXPLAYERS+1] = Colour_Default;

//OnPluginStart
public void Highlights_OnPluginStart()
{
  HookEvent("round_prestart", Highlights_Reset, EventHookMode_Post);
}

//OnClientPutInServer
public void Highlights_OnClientPutInServer(int client)
{
  //Disable highlighting
  s_IsHighlighted[client] = false;
}

//Round pre start
public void Highlights_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Unhighlight
    if (s_IsHighlighted[i] && IsPlayerAlive(i)) {
      SetEntityRenderColor(i, g_Colours_Full[0], g_Colours_Full[1], g_Colours_Full[2], g_Colours_Full[3]);
    }
    
    s_IsHighlighted[i] = false;
    s_HighlightedColour[i] = Colour_Default;
  }
}

//Clear all highlights
public void Highlights_ClearHighlights()
{
  //Iterate through all T's
  for (int i = 1; i <= MaxClients ; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        Highlights_SetIsHighlighted(i, false);
        Highlights_SetHighlightedColour(i, Colour_Default);
      }
    }
  }
}

//Getters/Setters

public bool Highlights_IsHighlighted(int client)
{
  return s_IsHighlighted[client];
}

public void Highlights_SetIsHighlighted(int client, bool value)
{
  s_IsHighlighted[client] = value;
}

public Colour Highlights_GetHighlightedColour(int client)
{
  return s_HighlightedColour[client];
}

public void Highlights_SetHighlightedColour(int client, Colour colourCode)
{
  s_HighlightedColour[client] = colourCode;
  int colour[4];
  Colours_GetColourFromColourCode(colourCode, colour);
  
  //Set Render colour
  SetEntityRenderColor(client, colour[0], colour[1], colour[2], colour[3]);
}