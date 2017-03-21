#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <wardentools>
#include <warden>
#include "colors_csgo.inc"
#include "emitsoundany.inc"

#pragma semicolon 1
#pragma newdecls required

//Menus
Menu MainMenu = null;
Menu DrawMenu = null;
Menu GameMenu = null;
Menu SpecialDaysMenu = null;
Menu SetColourMenu = null;
Menu BeamTypeMenu = null;
Menu BeamOptionsMenu = null;
Menu BeamDurationMenu = null;
Menu BeamParticleStyleMenu = null;

//Preference Cookies
Handle c_colour = null;
Handle c_beamtype = null;
Handle c_beamduration = null;
Handle c_beamparticlestyle = null;

//Flags
AdminFlag vipFlag = Admin_Custom3;

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
  Laser_OnPluginStart();
  Highlights_OnPluginStart();
  Freezebomb_OnPluginStart();
  Blind_OnPluginStart();
  Shark_OnPluginStart();
  Teamdeathmatch_OnPluginStart();
  Miccheck_OnPluginStart();
  Priorityspeaker_OnPluginStart();
  Specialdays_OnPluginStart();
  
  //Setup cookies
  c_colour = RegClientCookie("WardenTools_Colour", "The selected plain colour", CookieAccess_Private);
  c_beamtype = RegClientCookie("WardenTools_BeamType", "The selected beam type", CookieAccess_Private);
  c_beamduration = RegClientCookie("WardenTools_BeamDuration", "The duration of time beams last for", CookieAccess_Private);
  c_beamparticlestyle = RegClientCookie("WardenTools_BeamParticleStyle", "The style to use with particle beams", CookieAccess_Private);
    
  //Create Menus
  SetupMenus();
  
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
  newRoundTimeElapsed = GetTime();
}

/*********************************
 *  Commands
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
  
  DisplayMenu(MainMenu, client, MENU_TIME_FOREVER);
  
  return Plugin_Handled;
}

/*********************************
 *  Menus and Handlers
 *********************************/
//Setup all menus program will use
void SetupMenus()
{
  //Delete old menus
  if (MainMenu != null)
    delete MainMenu;
  
  if (DrawMenu != null)
    delete DrawMenu;
    
  if (GameMenu != null)
    delete GameMenu;
    
  if (SpecialDaysMenu != null)
    delete SpecialDaysMenu;
  
  if (SetColourMenu != null)
    delete SetColourMenu;
    
  if (BeamTypeMenu != null)
    delete BeamTypeMenu;
    
  if (BeamOptionsMenu != null)
    delete BeamOptionsMenu;
   
  if (BeamDurationMenu != null)
    delete BeamDurationMenu;
    
  if (BeamParticleStyleMenu != null)
    delete BeamParticleStyleMenu;
   
  //Main menu
  MainMenu = CreateMenu(MainMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  
  char mainMenuTitle[255];
  Format(mainMenuTitle, sizeof(mainMenuTitle), "Warden Tools (%s)", WT_VERSION);
  SetMenuTitle(MainMenu, mainMenuTitle);
  
  SetMenuExitButton(MainMenu, true);
  
  AddMenuItem(MainMenu, "Option_DrawTools", "Draw Tools");
  AddMenuItem(MainMenu, "Option_GameTools", "Game Tools");
  AddMenuItem(MainMenu, "Option_SpecialDay", "Special Days");
  AddMenuItem(MainMenu, "Option_MicCheck", "Perform Mic Check");
  AddMenuItem(MainMenu, "Option_PriorityToggle", "Priority Speaker [Toggle]");
  
  //Draw Menu
  DrawMenu = CreateMenu(DrawMenuHandler);
  SetMenuTitle(DrawMenu, "Draw Tools");
  SetMenuExitBackButton(DrawMenu, true);
  
  AddMenuItem(DrawMenu, "Option_SpawnBeam", "Spawn Beam");
  AddMenuItem(DrawMenu, "Option_SetColour", "Set Colour");
  AddMenuItem(DrawMenu, "Option_BeamOptions", "Configure Beams");
  AddMenuItem(DrawMenu, "Option_Laser", "Laser [Toggle]");
  AddMenuItem(DrawMenu, "Option_Highlight", "Highlight Prisoner [Toggle]");
  AddMenuItem(DrawMenu, "Option_ClearHighlight", "Clear Highlights");
  
  //Game Menu
  GameMenu = CreateMenu(GameMenuHandler);
  SetMenuTitle(GameMenu, "Game Tools");
  SetMenuExitBackButton(GameMenu, true);
  
  AddMenuItem(GameMenu, "Option_SetHealth", "Reset T Health (100hp)");
  AddMenuItem(GameMenu, "Option_Freezebomb", "Freezebomb Prisoners (Toggle)");
  AddMenuItem(GameMenu, "Option_Blind", "Blind Prisoners (Toggle)");
  AddMenuItem(GameMenu, "Option_CTShark", "Make CT Shark (30 seconds)");
  AddMenuItem(GameMenu, "Option_HighlightedDM", "Highlighted Team Deathmatch (Toggle)");
  AddMenuItem(GameMenu, "Option_Slap", "Slap Prisoners");
  
  //Special Days Menu
  SpecialDaysMenu = CreateMenu(SpecialDaysMenuHandler);
  SetMenuTitle(SpecialDaysMenu, "Select a Special Day");
  SetMenuExitBackButton(SpecialDaysMenu, true);
  
  //Add menu items for all registered special days
  for(int i = 0; i < Specialdays_GetSpecialDayCount(); ++i) {
    AddMenuItem(SpecialDaysMenu, specialDayList[i][dayName], specialDayList[i][dayName]);
  }
  
  //Set Colour Menu
  SetColourMenu = CreateMenu(SetColourMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(SetColourMenu, "Select Beam Colour");
  SetMenuExitBackButton(SetColourMenu, true);
  
  char colourBuffer[8];
  IntToString(COLOURS_RED, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Red");
  IntToString(COLOURS_GREEN, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Green");
  IntToString(COLOURS_BLUE, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Blue");
  IntToString(COLOURS_PURPLE, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Purple");
  IntToString(COLOURS_YELLOW, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Yellow");
  IntToString(COLOURS_CYAN, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Cyan");
  IntToString(COLOURS_PINK, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Pink");
  IntToString(COLOURS_ORANGE, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Orange");
  IntToString(COLOURS_WHITE, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "White");
  IntToString(COLOURS_BLACK, colourBuffer, sizeof(colourBuffer));
  AddMenuItem(SetColourMenu, colourBuffer, "Black");

  
  //Beam Options Menu
  BeamOptionsMenu = CreateMenu(BeamOptionsMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(BeamOptionsMenu, "Configure Beams");
  SetMenuExitBackButton(BeamOptionsMenu, true);
  
  AddMenuItem(BeamOptionsMenu, "Option_BeamType", "Set Beam Type");
  AddMenuItem(BeamOptionsMenu, "Option_BeamDuration", "Toggle Beam Duration");
  AddMenuItem(BeamOptionsMenu, "Option_BeamParticleStyle", "Set Particle Beam Style");
  
  //Beam Type Menu
  BeamTypeMenu = CreateMenu(BeamTypeMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(BeamTypeMenu, "Set Beam Type");
  SetMenuExitBackButton(BeamTypeMenu, true);
  
  char beamTypeBuffer[8];
  IntToString(BEAMTYPE_COLOUR, beamTypeBuffer, sizeof(beamTypeBuffer));
  AddMenuItem(BeamTypeMenu, beamTypeBuffer, "Plain Colour Beams");
  IntToString(BEAMTYPE_PARTICLE, beamTypeBuffer, sizeof(beamTypeBuffer));
  AddMenuItem(BeamTypeMenu, beamTypeBuffer, "Particle Beams");
  
  //Beam Duration Menu
  BeamDurationMenu = CreateMenu(BeamDurationMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(BeamDurationMenu, "Select Beam Display Time");
  SetMenuExitBackButton(BeamDurationMenu, true);

  AddMenuItem(BeamDurationMenu, "10", "Last 10 seconds");
  AddMenuItem(BeamDurationMenu, "20", "Last 20 seconds");
  AddMenuItem(BeamDurationMenu, "30", "Last 30 seconds");
  AddMenuItem(BeamDurationMenu, "40", "Last 40 seconds");
  AddMenuItem(BeamDurationMenu, "50", "Last 50 seconds");
  AddMenuItem(BeamDurationMenu, "60", "Last 60 seconds");
  
  //Beam Particle Style Menu
  BeamParticleStyleMenu = CreateMenu(BeamParticleStyleMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(BeamParticleStyleMenu, "Select a Particle Beam Style");
  SetMenuExitBackButton(BeamParticleStyleMenu, true);
  
  //Add menu items for all registered special days
  for(int i = 0; i < Particlebeams_GetNumParticleStyles(); ++i) {
    char buffer[4];
    IntToString(i, buffer, sizeof(buffer));
    AddMenuItem(BeamParticleStyleMenu, buffer, Particlebeams_List[i][szNiceName]);
  }
}
 
//Handles main Menu
public int MainMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  char info[32];
  GetMenuItem(menu, itemNum, info, sizeof(info));

  if (action == MenuAction_DrawItem) {
    if (StrEqual(info, "Option_DrawTools")) {
      if (Specialdays_IsSpecialDay() && !specialDayList[Specialdays_GetSpecialDay()][allowDrawTools]) {
        return ITEMDRAW_DISABLED;
      }
    }
    else if (StrEqual(info, "Option_GameTools")) {
      //Game tools only enabled on non-special days
      if (Specialdays_IsSpecialDay())
        return ITEMDRAW_DISABLED;
    }
    else if (StrEqual(info, "Option_SpecialDay")) {
      if (!Specialdays_CanStartSpecialDay())
        return ITEMDRAW_DISABLED;
    }
    else if (StrEqual(info, "Option_MicCheck")) {
      if (Miccheck_IsMicCheckConducted())
        return ITEMDRAW_DISABLED;
    }
  }
  else if (action == MenuAction_DisplayItem) {
    if (StrEqual(info, "Option_SpecialDay")) {
      char specialDayText[64];
      Format(specialDayText, sizeof(specialDayText), "Special Days (%d left)", Specialdays_GetNumSpecialDaysLeft());
      return RedrawMenuItem(specialDayText);
    }
  }
  else if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return 0;
    }
    
    if (StrEqual(info, "Option_DrawTools")) {
      DisplayMenu(DrawMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_GameTools")) {
      DisplayMenu(GameMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_SpecialDay")) {
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
  
  return 0;
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
      DisplayMenu(SetColourMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_BeamOptions")) {
      DisplayMenu(BeamOptionsMenu, client, MENU_TIME_FOREVER);
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

//Handle beam options menu
public int BeamOptionsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  GetMenuItem(menu, param2, info, sizeof(info));

  if (action == MenuAction_DrawItem) {
    if (StrEqual(info, "Option_BeamParticleStyle")) {
      if (Beams_GetBeamType() != BEAMTYPE_PARTICLE)
        return ITEMDRAW_DISABLED;
    }
  }
  else if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return 0;
    }
    
    if (StrEqual(info, "Option_BeamType")) {
      DisplayMenu(BeamTypeMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_BeamDuration")) {
      DisplayMenu(BeamDurationMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_BeamParticleStyle")) {
      DisplayMenu(BeamParticleStyleMenu, client, MENU_TIME_FOREVER);
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
  
  return 0;
}

//Handle duration type menu
public int BeamTypeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  int temp;
  char display[64];
  GetMenuItem(menu, param2, info, sizeof(info), temp, display, sizeof(display));
  
  int beamType = StringToInt(info);

  if (action == MenuAction_DrawItem) {
    if (beamType == Beams_GetBeamType()) {
      return ITEMDRAW_DISABLED;
    }
    else if (beamType == BEAMTYPE_PARTICLE) {
      int isVIP = CheckCommandAccess(client, "", FlagToBit(vipFlag));
      if (!isVIP)
        return ITEMDRAW_DISABLED;
    }
  }
  else if (action == MenuAction_DisplayItem) {
    if (beamType == Beams_GetBeamType()) {
      char selectedBeamTypeText[64];
      Format(selectedBeamTypeText, sizeof(selectedBeamTypeText), "%s [*]", display);
      return RedrawMenuItem(selectedBeamTypeText);
    }
    else if (beamType == BEAMTYPE_PARTICLE) {
      int isVIP = CheckCommandAccess(client, "", FlagToBit(vipFlag));
      if (!isVIP) {
        char particleBeamText[64];
        Format(particleBeamText, sizeof(particleBeamText), "Particle Beams (VIP Only)");
        return RedrawMenuItem(particleBeamText);
      }
    }
  }
  else if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return 0;
    }    
    
    //Set Beam Type to selected option
    Beams_SetBeamType(beamType);
    
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Beam Type Set", display);
    
    //Go back to parent menu
    DisplayMenuAtItem(BeamTypeMenu, client, GetMenuSelectionPosition(), 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(BeamOptionsMenu, client, 0, 0);
    }
  }
  
  return 0;
}

//Handle duration menu
public int BeamDurationMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  int temp;
  char display[64];
  GetMenuItem(menu, param2, info, sizeof(info), temp, display, sizeof(display));

  if (action == MenuAction_DrawItem) {
    if (StringToFloat(info) == Beams_GetBeamDuration())
        return ITEMDRAW_DISABLED;
  }
  else if (action == MenuAction_DisplayItem) {
    if (StringToFloat(info) == Beams_GetBeamDuration()) {
      char selectedDurationText[64];
      Format(selectedDurationText, sizeof(selectedDurationText), "%s [*]", display);
      return RedrawMenuItem(selectedDurationText);
    }
  }
  else if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return 0;
    }
    
    float newDuration = StringToFloat(info);
    
    Beams_SetDuration(newDuration);
    
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Duration Set", newDuration);
    
    //Go back to parent menu
    DisplayMenuAtItem(BeamDurationMenu, client, GetMenuSelectionPosition(), 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(BeamOptionsMenu, client, 0, 0);
    }
  }
  
  return 0;
}

//Handle beam particle style
public int BeamParticleStyleMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  int temp;
  char display[64];
  GetMenuItem(menu, param2, info, sizeof(info), temp, display, sizeof(display));

  int particleBeamStyle = StringToInt(info);
  
  if (action == MenuAction_DrawItem) {
    if (particleBeamStyle == Particlebeams_GetStyle())
      return ITEMDRAW_DISABLED;
  }
  else if (action == MenuAction_DisplayItem) {
    if (particleBeamStyle == Particlebeams_GetStyle()) {
      char selectedParticleBeamStyleText[64];
      Format(selectedParticleBeamStyleText, sizeof(selectedParticleBeamStyleText), "%s [*]", display);
      return RedrawMenuItem(selectedParticleBeamStyleText);
    }
  }
  else if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return 0;
    }
    
    Particlebeams_SetStyle(particleBeamStyle);
    
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Beam Style Set", display);
    
    //Go back to parent menu
    DisplayMenuAtItem(BeamParticleStyleMenu, client, GetMenuSelectionPosition(), 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(BeamOptionsMenu, client, 0, 0);
    }
  }
  
  return 0;
}

//Handle colour menu
public int SetColourMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  int temp;
  char display[64];
  GetMenuItem(menu, param2, info, sizeof(info), temp, display, sizeof(display));
  
  int colourCode = StringToInt(info);

  if (action == MenuAction_DrawItem) {
    //Disable currently selected colour
    if (colours_currentColourCode == colourCode)
        return ITEMDRAW_DISABLED;
  }
  else if (action == MenuAction_DisplayItem) {
    if (colours_currentColourCode == colourCode) {
      char selectedColourText[64];
      Format(selectedColourText, sizeof(selectedColourText), "%s [*]", display);
      return RedrawMenuItem(selectedColourText);
    }
  }
  else if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return 0;
    }
    
    //Set colour code
    colours_currentColourCode = colourCode;
    
    //Set current colour
    int newColour[4];
    Colours_GetColourFromColourCode(colourCode, newColour);
    Colours_SetCurrentColour(newColour);
    
    //Print message
    if (colourCode == COLOURS_RED) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "darkred", "red");
     }
    else if (colourCode == COLOURS_GREEN) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightgreen", "green");
    }
    else if (colourCode == COLOURS_BLUE) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "blue", "blue");
    }
    else if (colourCode == COLOURS_PURPLE) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "purple", "purple");
    }
    else if (colourCode == COLOURS_YELLOW) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "olive", "yellow");
    }
    else if (colourCode == COLOURS_CYAN) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightblue", "cyan");
    }
    else if (colourCode == COLOURS_PINK) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "pink");
    }
    else if (colourCode == COLOURS_ORANGE) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "orange");
    }
    else if (colourCode == COLOURS_WHITE) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "white");
    }
    else if (colourCode == COLOURS_BLACK) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "black");
    }
    
    //Go back to draw menu again
    DisplayMenuAtItem(SetColourMenu, client, GetMenuSelectionPosition(), 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
  
  return 0;
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

/*********************************
 * Global Forwards
 *********************************/

public void warden_OnWardenCreated(int warden)
{
  //Load preferences from cookies for new warden
  if (AreClientCookiesCached(warden)) {
    char buffer[16];
  
    //c_colour
    GetClientCookie(warden, c_colour, buffer, sizeof(buffer));
    
    if (strlen(buffer) == 0) { //Set default values for empty cookie
      Colours_SetCurrentColour(colours_red);
      colours_currentColourCode = COLOURS_RED; 
    } else {
      int colourCode = StringToInt(buffer);
      int newColour[4];
      Colours_GetColourFromColourCode(colourCode, newColour); //get colour from code
      Colours_SetCurrentColour(newColour); //set colour values
      colours_currentColourCode = colourCode; //set colour code
    }
    
    //c_beamtype
    GetClientCookie(warden, c_beamtype, buffer, sizeof(buffer));
    if (strlen(buffer) == 0) //Set default values for empty cookie
      Beams_SetBeamType(BEAMTYPE_COLOUR);
    else
      Beams_SetBeamType(StringToInt(buffer));
    
    //c_beamduration
    GetClientCookie(warden, c_beamduration, buffer, sizeof(buffer));
    if (strlen(buffer) == 0) //Set default values for empty cookie
      Beams_SetDuration(BEAM_DEFAULT_DURATION);
    else
      Beams_SetDuration(StringToFloat(buffer));
    
    //c_beamparticlestyle
    GetClientCookie(warden, c_beamparticlestyle, buffer, sizeof(buffer));
    if (strlen(buffer) == 0) //Set default values for empty cookie
      Particlebeams_SetStyle(DEFAULT_PARTICLEBEAMS_STYLE);
    else
      Particlebeams_SetStyle(StringToInt(buffer));
  }
  
  //Check beam type status
  int isVIP = CheckCommandAccess(warden, "", FlagToBit(vipFlag));
  if (!isVIP && Beams_GetBeamType() == BEAMTYPE_PARTICLE) {
    Beams_SetBeamType(BEAMTYPE_COLOUR);
  }
}

public void warden_OnWardenRemoved(int warden)
{
  //Save preferences as cookies
  if (AreClientCookiesCached(warden)) {
    char buffer[16];
    
    //c_colour
    IntToString(colours_currentColourCode, buffer, sizeof(buffer));
    SetClientCookie(warden, c_colour, buffer);
    
    //c_beamtype
    IntToString(Beams_GetBeamType(), buffer, sizeof(buffer));
    SetClientCookie(warden, c_beamtype, buffer);
    
    //c_beamduration
    FloatToString(Beams_GetBeamDuration(), buffer, sizeof(buffer));
    SetClientCookie(warden, c_beamduration, buffer);
    
    //c_beamparticlestyle
    IntToString(Particlebeams_GetStyle(), buffer, sizeof(buffer));
    SetClientCookie(warden, c_beamparticlestyle, buffer);
  }
  
  //Remove menus if warden removed
  if (IsClientInGame(warden)) {
    //Kill all menus for warden
    CancelClientMenu(warden);
  }
}