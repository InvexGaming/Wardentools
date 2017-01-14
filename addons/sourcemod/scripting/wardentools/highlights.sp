/*
* Highlight players with various colours that can be used by other modules
* Prefix: highlights_
*/

#if defined _wardentools_highlights_included
  #endinput
#endif
#define _wardentools_highlights_included

#include <wardentools>
#include "wardentools/colours.sp"

//Static Globals
static bool isHighlighted[MAXPLAYERS+1] = false;
static int highlightedColour[MAXPLAYERS+1] = COLOURS_DEFAULT;

//OnPluginStart
public void Highlights_OnPluginStart()
{
  HookEvent("round_prestart", Highlights_Reset, EventHookMode_Post);
}

//OnClientPutInServer
public void Highlights_OnClientPutInServer(int client)
{
  //Disable highlighting
  isHighlighted[client] = false;
}

//Round pre start
public void Highlights_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Unhighlight
    if (isHighlighted[i] && IsPlayerAlive(i)) {
      SetEntityRenderColor(i, colours_full[0], colours_full[1], colours_full[2], colours_full[3]);
    }
    
    isHighlighted[i] = false;
    highlightedColour[i] = COLOURS_DEFAULT;
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
        Highlights_SetHighlightedColour(i, COLOURS_DEFAULT);
      }
    }
  }
}

//Getters/Setters

public bool Highlights_IsHighlighted(int client)
{
  return isHighlighted[client];
}

public void Highlights_SetIsHighlighted(int client, bool value)
{
  isHighlighted[client] = value;
}

public int Highlights_GetHighlightedColour(int client)
{
  return highlightedColour[client];
}

public void Highlights_SetHighlightedColour(int client, int colourCode)
{
  highlightedColour[client] = colourCode;
  int colour[4];
  Colours_GetColourFromColourCode(colourCode, colour);
  
  //Set Render colour
  SetEntityRenderColor(client, colour[0], colour[1], colour[2], colour[3]);
}