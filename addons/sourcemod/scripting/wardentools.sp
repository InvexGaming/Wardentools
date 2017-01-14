#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <wardentools>
#include <warden>
#include "colors_csgo.inc"
#include "emitsoundany.inc"

#pragma semicolon 1
#pragma newdecls required

//Menus
Menu MainMenu = null;
Menu GameMenu = null;
Menu DrawMenu = null;
Menu SpecialDaysMenu = null;

//Settings
int newRoundTimeElapsed = 0;

/*********************************
 *   Module Includes
 *********************************/
#include "wardentools/beams.sp"
#include "wardentools/colours.sp"
#include "wardentools/laser.sp"
#include "wardentools/highlights.sp"
#include "wardentools/sethealth.sp"
#include "wardentools/freezebomb.sp"
#include "wardentools/blind.sp"
#include "wardentools/shark.sp"
#include "wardentools/teamdeathmatch.sp"
#include "wardentools/slap.sp"
#include "wardentools/miccheck.sp"
#include "wardentools/priorityspeaker.sp"
#include "wardentools/specialdays.sp"

//Plugin Info
public Plugin myinfo =
{
  name = "Jailbreak Warden Tools",
  author = "Invex | Byte",
  description = "Tools to help the warden...warden.",
  version = WT_VERSION,
  url = "http://www.invexgaming.com.au"
};

/*********************************
 *   Fowards
 *********************************/

// Plugin Start
public void OnPluginStart()
{
  //Translations
  LoadTranslations("wardentools.phrases");
  
  //Flags
  CreateConVar("sm_wt_version", WT_VERSION, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
  
  RegConsoleCmd("sm_wt", Command_WT_Menu, "Bring up warden tools menu");
  RegConsoleCmd("sm_wardentools", Command_WT_Menu, "Bring up warden tools menu");
  
  //Update new round time start
  newRoundTimeElapsed = GetTime();
  
  //Hooks
  HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_Post);
  
  //Modules OnPluginStart
  Beams_OnPluginStart();
  Colours_OnPluginStart();
  Laser_OnPluginStart();
  Highlights_OnPluginStart();
  Freezebomb_OnPluginStart();
  Blind_OnPluginStart();
  Shark_OnPluginStart();
  Teamdeathmatch_OnPluginStart();
  Miccheck_OnPluginStart();
  Priorityspeaker_OnPluginStart();
  Specialdays_OnPluginStart();
  
  //SDKHooks
  int iMaxClients = GetMaxClients();
  
  for (int i = 1; i <= iMaxClients; ++i) {
    if (IsClientInGame(i)) {
      OnClientPutInServer(i);
    }
  }
  
  //Create config file
  AutoExecConfig(true, "wardentools");
}

// On map start
public void OnMapStart()
{
  //Modules
  Beams_OnMapStart();
  Laser_OnMapStart();
  Specialdays_OnMapStart();
}

//Client put in server
public void OnClientPutInServer(int client)
{
  //Modules
  Laser_OnClientPutInServer(client);
  Highlights_OnClientPutInServer(client);
  Shark_OnClientPutInServer(client);
  Teamdeathmatch_OnClientPutInServer(client);
  Specialdays_OnClientPutInServer(client);
}

/*********************************
 *  Events
 *********************************/
//Round pre start
public void Event_RoundPreStart(Handle event, const char[] name, bool dontBroadcast)
{
  //Close menu handler when round starts/ends
  if (MainMenu != null) delete MainMenu;
  if (GameMenu != null) delete GameMenu;
  if (DrawMenu != null) delete DrawMenu;
  if (SpecialDaysMenu != null) delete SpecialDaysMenu;
  
  newRoundTimeElapsed = GetTime();
}

//Remove menus if warden is removed
public void warden_OnWardenRemoved(int warden)
{
  if (IsClientInGame(warden)) {
    //Kill all menus for warden
    CancelClientMenu(warden);
    
    //Close menu handlers
    if (MainMenu != null) delete MainMenu;
    if (GameMenu != null) delete GameMenu;
    if (DrawMenu != null) delete DrawMenu;
    if (SpecialDaysMenu != null) delete SpecialDaysMenu;
  }
}

/*********************************
 *  Console Commands
 *********************************/

//Show WT Menu
public Action Command_WT_Menu(int client, int args)
{
  if (client == 0) {  // Prevent command usage from server input and via RCON
    PrintToConsole(client, "Can't use this command from server input.");
    return Plugin_Handled;
  }
  
  //Ensure team is CT
  if (GetClientTeam(client) != CS_TEAM_CT) { 
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "CT Only Command");
    return Plugin_Handled;
  }
  
  //Ensure user is warden
  bool isWarden = view_as<bool>(warden_iswarden(client));
  
  if (!isWarden) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
    return Plugin_Handled;
  }
  
  //Create menu
  MainMenu = CreateMenu(MainMenuHandler);
  char mainMenuTitle[255];
  Format(mainMenuTitle, sizeof(mainMenuTitle), "Warden Tools (%s)", WT_VERSION);
  SetMenuTitle(MainMenu, mainMenuTitle);
  
  //Add menu items
  if (!Specialdays_IsSpecialDay() || (Specialdays_IsSpecialDay() && (specialDayList[Specialdays_GetSpecialDay()][allowDrawTools])))
    AddMenuItem(MainMenu, "Option_DrawTools", "Draw Tools");
  else
    AddMenuItem(MainMenu, "Option_DrawTools", "Draw Tools", ITEMDRAW_DISABLED);
  
  //Game tools only enabled on non-special days or on round modifier days
  if (!Specialdays_IsSpecialDay())  
    AddMenuItem(MainMenu, "Option_GameTools", "Game Tools");
  else
    AddMenuItem(MainMenu, "Option_GameTools", "Game Tools", ITEMDRAW_DISABLED);
    
  //Disable special day menu if one already running
  char specialDayText[64];
  Format(specialDayText, sizeof(specialDayText), "Special Days (%d left)", Specialdays_GetNumSpecialDaysLeft());
  
  if (!Specialdays_CanStartSpecialDay())
    AddMenuItem(MainMenu, "Option_SpecialDay", specialDayText, ITEMDRAW_DISABLED);
  else
    AddMenuItem(MainMenu, "Option_SpecialDay", specialDayText);
   
  if (Miccheck_IsMicCheckConducted())
    AddMenuItem(MainMenu, "Option_MicCheck", "Perform Mic Check", ITEMDRAW_DISABLED);
  else
    AddMenuItem(MainMenu, "Option_MicCheck", "Perform Mic Check");
  
  AddMenuItem(MainMenu, "Option_PriorityToggle", "Priority Speaker [Toggle]");
  
  DisplayMenu(MainMenu, client, MENU_TIME_FOREVER);
  
  return Plugin_Handled;
}


/*********************************
 *  Menus and Handlers
 *********************************/

//Handles main Menu
public int MainMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_DrawTools")) {
      //Create menu
      DrawMenu = CreateMenu(DrawMenuHandler);
      SetMenuExitBackButton(DrawMenu, true);
      SetMenuTitle(DrawMenu, "Use a drawing tool");
      
      //Add menu items
      AddMenuItem(DrawMenu, "Option_SpawnBeam", "Spawn Beam");
      AddMenuItem(DrawMenu, "Option_SetColour", "Set Colour");
      AddMenuItem(DrawMenu, "Option_BeamDuration", "Toggle Beam Duration");
      AddMenuItem(DrawMenu, "Option_Laser", "Laser [Toggle]");
      AddMenuItem(DrawMenu, "Option_Highlight", "Highlight Prisoner [Toggle]");
      AddMenuItem(DrawMenu, "Option_ClearHighlight", "Clear Highlights");

      DisplayMenu(DrawMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_GameTools")) {
      //Create menu
      GameMenu = CreateMenu(GameMenuHandler);
      SetMenuExitBackButton(GameMenu, true);
      SetMenuTitle(GameMenu, "Select an effect");
      
      //Add menu items
      AddMenuItem(GameMenu, "Option_SetHealth", "Reset T Health (100hp)");
      AddMenuItem(GameMenu, "Option_Freezebomb", "Freezebomb Prisoners (Toggle)");
      AddMenuItem(GameMenu, "Option_Blind", "Blind Prisoners (Toggle)");
      AddMenuItem(GameMenu, "Option_CTShark", "Make CT Shark (30 seconds)");
      AddMenuItem(GameMenu, "Option_HighlightedDM", "Highlighted Team Deathmatch (Toggle)");
      AddMenuItem(GameMenu, "Option_Slap", "Slap Prisoners");
      
      DisplayMenu(GameMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_SpecialDay")) {
      //Create menu
      SpecialDaysMenu = CreateMenu(SpecialDaysMenuHandler);
      SetMenuExitBackButton(SpecialDaysMenu, true);
      SetMenuTitle(SpecialDaysMenu, "Select a Special Day");
      
      //Add menu items for all registered special days
      for(int i = 0; i < Specialdays_GetSpecialDayCount(); ++i) {
        AddMenuItem(SpecialDaysMenu, specialDayList[i][dayName], specialDayList[i][dayName]);
      }
      
      DisplayMenu(SpecialDaysMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_MicCheck")) {
      Miccheck_PerformCommand(client, 0);
    }
    else if (StrEqual(info, "Option_PriorityToggle")) {
      Priorityspeaker_Toggle();
      
      DisplayMenu(MainMenu, client, MENU_TIME_FOREVER);
    }
  }
}

//Handle duration menu
public int DurationMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_10seconds")) {
      Beams_SetDuration(10.0);
    }
    else if (StrEqual(info, "Option_20seconds")) {
      Beams_SetDuration(20.0);
    }
    else if (StrEqual(info, "Option_30seconds")) {
      Beams_SetDuration(30.0);
    }
    else if (StrEqual(info, "Option_40seconds")) {
      Beams_SetDuration(40.0);
    }
    else if (StrEqual(info, "Option_50seconds")) {
      Beams_SetDuration(50.0);
    }
    else if (StrEqual(info, "Option_60seconds")) {
      Beams_SetDuration(60.0);
    }
    
    //Go back to main menu again
    DisplayMenuAtItem(DrawMenu, client, 0, 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
}

//Handle game tools menu
public int GameMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_Slap")) {
      Slap_SlapPrisoners();
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_Freezebomb")) {
      Freezebomb_ToggleFreezeBomb();
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_Blind")) {
      Blind_ToggleTeamBlind(CS_TEAM_T);
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_CTShark")) {
      //Create menu
      Menu SharkMenu = CreateMenu(SharkMenuHandler);
      SetMenuExitBackButton(SharkMenu, true);
      SetMenuTitle(SharkMenu, "Select a shark");

      char sName[MAX_NAME_LENGTH], sUserId[10];
      
      for (int i = 1; i <= MaxClients ; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_CT) {
            if (!Shark_IsShark(i)) { //Don't add current sharks
              GetClientName(i, sName, sizeof(sName));
              IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
              AddMenuItem(SharkMenu, sUserId, sName);
            }
          }
        }
      }
      
      DisplayMenu(SharkMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_HighlightedDM")) {
      //Highlighted Team DM
      if (Teamdeathmatch_IsInHighlightTeamDM()) {
        //Already in team DM, turn off
        Teamdeathmatch_TurnOff();
        
        DisplayMenuAtItem(GameMenu, client, 0, 0);
        return;
      }
      
      //Check if at least two teams exist
      int teamsLeft = Teamdeathmatch_GetNumTTeamsAlive();
      
      //Check if we can continue
      if (teamsLeft < 2) {
        DisplayMenuAtItem(GameMenu, client, 0, 0);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Not Enough Teams", 2);
        return;
      }
      
      //Otherwise, turn on Team DM
      Teamdeathmatch_TurnOn();
      
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_SetHealth")) {
      Sethealth_ResetTHealth();
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(MainMenu, client, 0, 0);
    }
  }
}

//Handle draw tools menu
public int DrawMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_SpawnBeam")) {
      //Spawn beam
      Beams_PlaceBeam(client);
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_SetColour")) {
      //Create menu
      Menu SetColourMenu = CreateMenu(SetColourMenuHandler);
      SetMenuExitBackButton(SetColourMenu, true);
      SetMenuTitle(SetColourMenu, "Select Beam Colour");

      //Add menu items
      AddMenuItem(SetColourMenu, "Option_ColourRed", "Red");
      AddMenuItem(SetColourMenu, "Option_ColourGreen", "Green");
      AddMenuItem(SetColourMenu, "Option_ColourBlue", "Blue");
      AddMenuItem(SetColourMenu, "Option_ColourPurple", "Purple");
      AddMenuItem(SetColourMenu, "Option_ColourYellow", "Yellow");
      AddMenuItem(SetColourMenu, "Option_ColourCyan", "Cyan");
      AddMenuItem(SetColourMenu, "Option_ColourPink", "Pink");
      AddMenuItem(SetColourMenu, "Option_ColourOrange", "Orange");
      AddMenuItem(SetColourMenu, "Option_ColourBlack", "Black");
      AddMenuItem(SetColourMenu, "Option_ColourWhite", "White");
      
      DisplayMenu(SetColourMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_BeamDuration")) {
      //Create menu
      Menu DurationMenu = CreateMenu(DurationMenuHandler);
      SetMenuExitBackButton(DurationMenu, true);
      SetMenuTitle(DurationMenu, "Select Beam Display Time");

      //Add menu items
      AddMenuItem(DurationMenu, "Option_10seconds", "Last 10 seconds");
      AddMenuItem(DurationMenu, "Option_20seconds", "Last 20 seconds");
      AddMenuItem(DurationMenu, "Option_30seconds", "Last 30 seconds");
      AddMenuItem(DurationMenu, "Option_40seconds", "Last 40 seconds");
      AddMenuItem(DurationMenu, "Option_50seconds", "Last 50 seconds");
      AddMenuItem(DurationMenu, "Option_60seconds", "Last 60 seconds");

      DisplayMenu(DurationMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_Laser")) {

      //Toggle Laser
      if (Laser_IsLaserEnabled(client))
        Laser_RemoveLaserAction(client, 0);
      else
        Laser_PlaceLaserAction(client, 0);
      
      //Go back to draw tools menu again
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_Highlight")) {
      if (Teamdeathmatch_IsInHighlightTeamDM()) {
        DisplayMenuAtItem(DrawMenu, client, 0, 0);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Can't Highlight");
        return;
      }
      
      //Get position client is looking at
      float hOrigin[3];
      GetAimOrigin(client, hOrigin, 2);
      
      //Iterate through all T's
      int playerToToggleHighlight = -1;
      float minDistance = 999999.9;
      
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T) {
            //Get player position
            float prisonerOrigin[3];
            GetClientAbsOrigin(i, prisonerOrigin);
            
            //Get position to hOrigin
            if (GetVectorDistance(prisonerOrigin, hOrigin, false) < minDistance) {
              minDistance = GetVectorDistance(prisonerOrigin, hOrigin, false);
              playerToToggleHighlight = i;
            }
          }
        }
      }
      
      //Highlight said player
      if (playerToToggleHighlight == -1 || minDistance > 100.0) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Highlight - No Player Found");
      }
      else {
        Highlights_SetIsHighlighted(playerToToggleHighlight, !Highlights_IsHighlighted(playerToToggleHighlight));
        
        if (Highlights_IsHighlighted(playerToToggleHighlight)) {
          Highlights_SetHighlightedColour(playerToToggleHighlight, colours_currentColourCode);
        }
        else {
          Highlights_SetHighlightedColour(playerToToggleHighlight, COLOURS_DEFAULT);
        }
      }
      
      //Go back to draw tools menu again
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_ClearHighlight")) {
      if (Teamdeathmatch_IsInHighlightTeamDM()) {
        DisplayMenuAtItem(DrawMenu, client, 0, 0);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Can't Highlight");
        return;
      }
      
      Highlights_ClearHighlights();
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Highlight - Removed from all", client);
      
      //Go back to draw tools menu again
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(MainMenu, client, 0, 0);
    }
  }
}

//Handle special days menu
public int SpecialDaysMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    //Check time in which special day was used
    if (GetTimeSinceRoundStart() >= Specialdays_GetSecondsToStartDay()) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Too Late", Specialdays_GetSecondsToStartDay());
      return;
    }
    
    char specialDayName[32];
    GetMenuItem(menu, param2, specialDayName, sizeof(specialDayName));
    
    //Start Special Day based on name
    Specialdays_StartSpecialDay(specialDayName);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(MainMenu, client, 0, 0);
    }
  }
}

//Handle colour menu
public int SetColourMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_ColourRed")) {
      //Red
      Colours_SetCurrentColour(colours_red);
      colours_currentColourCode = COLOURS_RED;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "darkred", "red");
    }
    else if (StrEqual(info, "Option_ColourGreen")) {
      //Green
      Colours_SetCurrentColour(colours_green);
      colours_currentColourCode = COLOURS_GREEN;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightgreen", "green");
    }
    else if (StrEqual(info, "Option_ColourBlue")) {
      //Blue
      Colours_SetCurrentColour(colours_blue);
      colours_currentColourCode = COLOURS_BLUE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "blue", "blue");
    }
    else if (StrEqual(info, "Option_ColourPurple")) {
      //Purple
      Colours_SetCurrentColour(colours_purple);
      colours_currentColourCode = COLOURS_PURPLE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "purple", "purple");
    }
    else if (StrEqual(info, "Option_ColourYellow")) {
      //Yellow
      Colours_SetCurrentColour(colours_yellow);
      colours_currentColourCode = COLOURS_YELLOW;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "olive", "yellow");
    }
    else if (StrEqual(info, "Option_ColourCyan")) {
      //Cyan
      Colours_SetCurrentColour(colours_cyan);
      colours_currentColourCode= COLOURS_CYAN;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightblue", "cyan");
    }
    else if (StrEqual(info, "Option_ColourPink")) {
      //Pink
      Colours_SetCurrentColour(colours_pink);
      colours_currentColourCode = COLOURS_PINK;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "pink");
    }
    else if (StrEqual(info, "Option_ColourOrange")) {
      //Orange
      Colours_SetCurrentColour(colours_orange);
      colours_currentColourCode = COLOURS_ORANGE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "orange");
    }
    else if (StrEqual(info, "Option_ColourWhite")) {
      //White
      Colours_SetCurrentColour(colours_white);
      colours_currentColourCode = COLOURS_WHITE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "white");
    }
    else if (StrEqual(info, "Option_ColourBlack")) {
      //Black
      Colours_SetCurrentColour(colours_black);
      colours_currentColourCode = COLOURS_BLACK;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "black");
    }
    
    //Go back to draw menu again
    DisplayMenuAtItem(DrawMenu, client, 0, 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
}

//Handle shark menu
public int SharkMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    int target = GetClientOfUserId(StringToInt(info));
    
    Shark_SetShark(target);
    
    //Go back to game menu again
    DisplayMenuAtItem(GameMenu, client, 0, 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
  }
}

/*********************************
 *  Helper Functions
 *********************************/

//Return time since new round started
int GetTimeSinceRoundStart()
{
  int curTime = GetTime();
  return (curTime - newRoundTimeElapsed);
}

stock int GetAimOrigin(int client, float hOrigin[3], int type) 
{
  float vAngles[3], fOrigin[3];
  GetClientEyePosition(client, fOrigin);
  GetClientEyeAngles(client, vAngles);

  Handle trace;
  if (type == 1)
    trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
  else if (type == 2)
    trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterOnlyPlayer, client);
  
  if (TR_DidHit(trace)) {
    TR_GetEndPosition(hOrigin, trace);
    CloseHandle(trace);
    return 1;
  }

  CloseHandle(trace);
  return 0;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, int data) 
{
  return (entity > MaxClients || !entity);
}

public bool TraceEntityFilterOnlyPlayer(int entity, int contentsMask, int data) 
{
  return data != entity;
}

//Helper function
void removeClientFromArray(ArrayList array, int client)
{
  while (FindValueInArray(array, client) != -1)
    RemoveFromArray(array, FindValueInArray(array, client));
}


/*********************************
 * Natives
 *********************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  CreateNative("WardenTools_IsSpecialDay", Native_IsSpecialDay);
  
  RegPluginLibrary("wardentools");
  
  return APLRes_Success;
}

public int Native_IsSpecialDay(Handle plugin, int numParams)
{
  return Specialdays_IsSpecialDay();
}