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

bool g_LateLoaded = false;

//Menus
Menu g_MainMenu = null;
Menu g_DrawMenu = null;
Menu g_GameMenu = null;
Menu g_SpecialDaysMenu = null;
Menu g_SetColourMenu = null;
Menu g_BeamTypeMenu = null;
Menu g_BeamOptionsMenu = null;
Menu g_BeamDurationMenu = null;
Menu g_BeamParticleStyleMenu = null;

//Preference Cookies
Handle g_ColourCookie = null; 
Handle g_BeamTypeCookie = null;
Handle g_BeamDurationCookie = null;
Handle g_BeamParticleStyleCookie = null;

//Flags
AdminFlag g_VipFlag = Admin_Custom3;

//Settings
int g_NewRoundTimeElapsed = 0;

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
#include "wardentools/esp.sp"

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  CreateNative("WardenTools_IsSpecialDay", Native_IsSpecialDay);
  
  RegPluginLibrary("wardentools");
  
  g_LateLoaded = late;
  
  return APLRes_Success;
}
 
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
  g_NewRoundTimeElapsed = GetTime();
  
  //Hooks
  HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_Post);
  
  //Modules OnPluginStart
  Beams_OnPluginStart();
  Laser_OnPluginStart();
  Highlights_OnPluginStart();
  FreezeBomb_OnPluginStart();
  Blind_OnPluginStart();
  Shark_OnPluginStart();
  TeamDeathmatch_OnPluginStart();
  MicCheck_OnPluginStart();
  PrioritySpeaker_OnPluginStart();
  SpecialDays_OnPluginStart();
  Esp_OnPluginStart();
  
  //Create config file
  AutoExecConfig(true, "wardentools");
  
  //Setup cookies
  g_ColourCookie = RegClientCookie("WardenTools_Colour", "The selected plain colour", CookieAccess_Private);
  g_BeamTypeCookie = RegClientCookie("WardenTools_BeamType", "The selected beam type", CookieAccess_Private);
  g_BeamDurationCookie = RegClientCookie("WardenTools_BeamDuration", "The duration of time beams last for", CookieAccess_Private);
  g_BeamParticleStyleCookie = RegClientCookie("WardenTools_BeamParticleStyle", "The style to use with particle beams", CookieAccess_Private);
    
  //Create Menus
  SetupMenus();
  
  //Late load our hook
  if (g_LateLoaded) {
    for (int i = 1; i <= MaxClients; ++i) {
      if (IsClientInGame(i))
        OnClientPutInServer(i);
    }
    
    g_LateLoaded = false;
  }
}

// On map start
public void OnMapStart()
{
  //Process players
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      OnClientPutInServer(i);
    }
  }

  //Modules
  Beams_OnMapStart();
  Laser_OnMapStart();
  SpecialDays_OnMapStart();
}

//Client put in server
public void OnClientPutInServer(int client)
{
  //Modules
  Laser_OnClientPutInServer(client);
  Highlights_OnClientPutInServer(client);
  Shark_OnClientPutInServer(client);
  TeamDeathmatch_OnClientPutInServer(client);
  SpecialDays_OnClientPutInServer(client);
}

/*********************************
 *  Events
 *********************************/
//Round pre start
public void Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast)
{
  g_NewRoundTimeElapsed = GetTime();
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
  
  DisplayMenu(g_MainMenu, client, MENU_TIME_FOREVER);
  
  return Plugin_Handled;
}

/*********************************
 *  Menus and Handlers
 *********************************/
//Setup all menus program will use
void SetupMenus()
{
  //Delete old menus
  delete g_MainMenu;
  delete g_DrawMenu;
  delete g_GameMenu;
  delete g_SpecialDaysMenu;
  delete g_SetColourMenu;
  delete g_BeamTypeMenu;
  delete g_BeamOptionsMenu;
  delete g_BeamDurationMenu;
  delete g_BeamParticleStyleMenu;
   
  //Main menu
  g_MainMenu = new Menu(MainMenuHandler, MenuAction_Select|MenuAction_DisplayItem|MenuAction_DrawItem);
  
  char mainMenuTitle[255];
  Format(mainMenuTitle, sizeof(mainMenuTitle), "Warden Tools (V%s)", WT_VERSION);
  g_MainMenu.SetTitle(mainMenuTitle);
  g_MainMenu.ExitButton = true;
  
  g_MainMenu.AddItem("Option_DrawTools", "Draw Tools");
  g_MainMenu.AddItem("Option_GameTools", "Game Tools");
  g_MainMenu.AddItem("Option_SpecialDay", "Special Days");
  g_MainMenu.AddItem("Option_MicCheck", "Perform Mic Check");
  g_MainMenu.AddItem("Option_PriorityToggle", "Priority Speaker [Toggle]");
  
  //Draw Menu
  g_DrawMenu = new Menu(DrawMenuHandler);
  g_DrawMenu.SetTitle("Draw Tools");
  g_DrawMenu.ExitBackButton = true;
  
  g_DrawMenu.AddItem("Option_SpawnBeam", "Spawn Beam");
  g_DrawMenu.AddItem("Option_SetColour", "Set Colour");
  g_DrawMenu.AddItem("Option_BeamOptions", "Configure Beams");
  g_DrawMenu.AddItem("Option_Laser", "Laser [Toggle]");
  g_DrawMenu.AddItem("Option_Highlight", "Highlight Prisoner [Toggle]");
  g_DrawMenu.AddItem("Option_ClearHighlight", "Clear Highlights");
  
  //Game Menu
  g_GameMenu = new Menu(GameMenuHandler);
  g_GameMenu.SetTitle("Game Tools");
  g_GameMenu.ExitBackButton = true;
  
  g_GameMenu.AddItem("Option_SetHealth", "Reset T Health (100hp)");
  g_GameMenu.AddItem("Option_Freezebomb", "Freezebomb Prisoners (Toggle)");
  g_GameMenu.AddItem("Option_Blind", "Blind Prisoners (Toggle)");
  g_GameMenu.AddItem("Option_CTShark", "Make CT Shark (30 seconds)");
  g_GameMenu.AddItem("Option_HighlightedDM", "Highlighted Team Deathmatch (Toggle)");
  g_GameMenu.AddItem("Option_Slap", "Slap Prisoners");
  
  //Special Days Menu
  g_SpecialDaysMenu = new Menu(SpecialDaysMenuHandler);
  g_SpecialDaysMenu.SetTitle("Select a Special Day");
  g_SpecialDaysMenu.ExitBackButton = true;
  
  //Add menu items for all registered special days
  for(int i = 0; i < SpecialDays_GetSpecialDayCount(); ++i) {
    g_SpecialDaysMenu.AddItem(g_SpecialDayList[i][dayName], g_SpecialDayList[i][dayName]);
  }
  
  //Set Colour Menu
  g_SetColourMenu = new Menu(SetColourMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem|MenuAction_DrawItem);
  g_SetColourMenu.SetTitle("Select Beam Colour");
  g_SetColourMenu.ExitBackButton = true;
  
  char colourBuffer[8];
  IntToString(view_as<int>(Colour_Red), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Red");
  IntToString(view_as<int>(Colour_Green), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Green");
  IntToString(view_as<int>(Colour_Blue), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Blue");
  IntToString(view_as<int>(Colour_Purple), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Purple");
  IntToString(view_as<int>(Colour_Yellow), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Yellow");
  IntToString(view_as<int>(Colour_Cyan), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Cyan");
  IntToString(view_as<int>(Colour_Pink), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Pink");
  IntToString(view_as<int>(Colour_Orange), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Orange");
  IntToString(view_as<int>(Colour_White), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "White");
  IntToString(view_as<int>(Colour_Black), colourBuffer, sizeof(colourBuffer));
  g_SetColourMenu.AddItem(colourBuffer, "Black");

  
  //Beam Options Menu
  g_BeamOptionsMenu = new Menu(BeamOptionsMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem|MenuAction_DrawItem);
  g_BeamOptionsMenu.SetTitle("Configure Beams");
  g_BeamOptionsMenu.ExitBackButton = true;
  
  g_BeamOptionsMenu.AddItem("Option_BeamType", "Set Beam Type");
  g_BeamOptionsMenu.AddItem("Option_BeamDuration", "Toggle Beam Duration");
  g_BeamOptionsMenu.AddItem("Option_BeamParticleStyle", "Set Particle Beam Style");
  
  //Beam Type Menu
  g_BeamTypeMenu = new Menu(BeamTypeMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem|MenuAction_DrawItem);
  g_BeamTypeMenu.SetTitle("Set Beam Type");
  g_BeamTypeMenu.ExitBackButton = true;
  
  char beamTypeBuffer[8];
  IntToString(view_as<int>(BeamType_Colour), beamTypeBuffer, sizeof(beamTypeBuffer));
  g_BeamTypeMenu.AddItem(beamTypeBuffer, "Plain Colour Beams");
  IntToString(view_as<int>(BeamType_Particle), beamTypeBuffer, sizeof(beamTypeBuffer));
  g_BeamTypeMenu.AddItem(beamTypeBuffer, "Particle Beams");
  
  //Beam Duration Menu
  g_BeamDurationMenu = new Menu(BeamDurationMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem|MenuAction_DrawItem);
  g_BeamDurationMenu.SetTitle("Select Beam Display Time");
  g_BeamDurationMenu.ExitBackButton = true;

  g_BeamDurationMenu.AddItem("10", "Last 10 seconds");
  g_BeamDurationMenu.AddItem("20", "Last 20 seconds");
  g_BeamDurationMenu.AddItem("30", "Last 30 seconds");
  g_BeamDurationMenu.AddItem("40", "Last 40 seconds");
  g_BeamDurationMenu.AddItem("50", "Last 50 seconds");
  g_BeamDurationMenu.AddItem("60", "Last 60 seconds");
  
  //Beam Particle Style Menu
  g_BeamParticleStyleMenu = new Menu(BeamParticleStyleMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem|MenuAction_DrawItem);
  g_BeamParticleStyleMenu.SetTitle("Select a Particle Beam Style");
  g_BeamParticleStyleMenu.ExitBackButton = true;
  
  //Add menu items for all registered special days
  for(int i = 0; i < ParticleBeams_GetNumParticleStyles(); ++i) {
    char buffer[4];
    IntToString(i, buffer, sizeof(buffer));
    g_BeamParticleStyleMenu.AddItem(buffer, ParticleBeams_List[i][szNiceName]);
  }
}

//Handles main Menu
public int MainMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  menu.GetItem(param2, info, sizeof(info));

  switch(action)
  {
    case MenuAction_DrawItem:
    {
      if (StrEqual(info, "Option_DrawTools")) {
        if (SpecialDays_IsSpecialDay() && !g_SpecialDayList[SpecialDays_GetSpecialDay()][allowDrawTools]) {
          return ITEMDRAW_DISABLED;
        }
      }
      else if (StrEqual(info, "Option_GameTools")) {
        //Game tools only enabled on non-special days
        if (SpecialDays_IsSpecialDay())
          return ITEMDRAW_DISABLED;
      }
      else if (StrEqual(info, "Option_SpecialDay")) {
        if (!SpecialDays_CanStartSpecialDay())
          return ITEMDRAW_DISABLED;
      }
      else if (StrEqual(info, "Option_MicCheck")) {
        if (MicCheck_IsMicCheckConducted())
          return ITEMDRAW_DISABLED;
      }
    }
    
    case MenuAction_DisplayItem:
    {
      if (StrEqual(info, "Option_SpecialDay")) {
        char specialDayText[64];
        Format(specialDayText, sizeof(specialDayText), "Special Days (%d left)", SpecialDays_GetNumSpecialDaysLeft());
        return RedrawMenuItem(specialDayText);
      }
    }
    
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return 0;
      }
      
      if (StrEqual(info, "Option_DrawTools")) {
        g_DrawMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_GameTools")) {
        g_GameMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_SpecialDay")) {
        g_SpecialDaysMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_MicCheck")) {
        MicCheck_PerformCommand(client, 0);
      }
      else if (StrEqual(info, "Option_PriorityToggle")) {
        PrioritySpeaker_Toggle();
        g_MainMenu.Display(client, MENU_TIME_FOREVER);
      }
    }
  }
  
  return 0;
}

//Handle draw tools menu
public int DrawMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  switch(action)
  {
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return;
      }
      
      char info[32];
      menu.GetItem(param2, info, sizeof(info));
      
      if (StrEqual(info, "Option_SpawnBeam")) {
        //Spawn beam
        Beams_PlaceBeam(client);
        g_DrawMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_SetColour")) {
        g_SetColourMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_BeamOptions")) {
        g_BeamOptionsMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_Laser")) {

        //Toggle Laser
        if (Laser_IsLaserEnabled(client))
          Laser_RemoveLaserAction(client, 0);
        else
          Laser_PlaceLaserAction(client, 0);
        
        //Go back to draw tools menu again
        g_DrawMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_Highlight")) {
        if (TeamDeathmatch_IsInHighlightTeamDM()) {
          g_DrawMenu.DisplayAt(client, 0, 0);
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Can't Highlight");
          return;
        }
        
        //Get position client is looking at
        int playerToToggleHighlight = GetClientAimPlayer(client);
        
        //Highlight said player
        if (playerToToggleHighlight == -1) {
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Highlight - No Player Found");
        }
        else {
          Highlights_SetIsHighlighted(playerToToggleHighlight, !Highlights_IsHighlighted(playerToToggleHighlight));
          
          if (Highlights_IsHighlighted(playerToToggleHighlight)) {
            Highlights_SetHighlightedColour(playerToToggleHighlight, g_Colours_CurrentColourCode);
          }
          else {
            Highlights_SetHighlightedColour(playerToToggleHighlight, Colour_Default);
          }
        }
        
        //Go back to draw tools menu again
        g_DrawMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_ClearHighlight")) {
        if (TeamDeathmatch_IsInHighlightTeamDM()) {
          g_DrawMenu.DisplayAt(client, 0, 0);
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Can't Highlight");
          return;
        }
        
        Highlights_ClearHighlights();
        
        CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Highlight - Removed from all", client);
        
        //Go back to draw tools menu again
        g_DrawMenu.DisplayAt(client, 0, 0);
      }
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_MainMenu.DisplayAt(client, 0, 0);
      }
    }
  }
}

//Handle game tools menu
public int GameMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  switch(action)
  {
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return;
      }
      
      char info[32];
      menu.GetItem(param2, info, sizeof(info));
      
      if (StrEqual(info, "Option_Slap")) {
        Slap_SlapPrisoners();
        g_GameMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_Freezebomb")) {
        FreezeBomb_ToggleFreezeBomb();
        g_GameMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_Blind")) {
        Blind_ToggleTeamBlind(CS_TEAM_T);
        g_GameMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_CTShark")) {
        //Create menu
        Menu sharkMenu = new Menu(SharkMenuHandler);
        sharkMenu.SetTitle("Select a shark");
        sharkMenu.ExitBackButton = true;

        char sName[MAX_NAME_LENGTH], sUserId[10];
        
        for (int i = 1; i <= MaxClients ; ++i) {
          if (IsClientInGame(i) && IsPlayerAlive(i)) {
            if (GetClientTeam(i) == CS_TEAM_CT) {
              if (!Shark_IsShark(i)) { //Don't add current sharks
                GetClientName(i, sName, sizeof(sName));
                IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
                sharkMenu.AddItem(sUserId, sName);
              }
            }
          }
        }
        sharkMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_HighlightedDM")) {
        //Highlighted Team DM
        if (TeamDeathmatch_IsInHighlightTeamDM()) {
          //Already in team DM, turn off
          TeamDeathmatch_TurnOff();
          
          g_GameMenu.DisplayAt(client, 0, 0);
          return;
        }
        
        //Check if at least two teams exist
        int teamsLeft = TeamDeathmatch_GetNumTTeamsAlive();
        
        //Check if we can continue
        if (teamsLeft < 2) {
          g_GameMenu.DisplayAt(client, 0, 0);
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Not Enough Teams", 2);
          return;
        }
        
        //Otherwise, turn on Team DM
        TeamDeathmatch_TurnOn();
        
        g_GameMenu.DisplayAt(client, 0, 0);
      }
      else if (StrEqual(info, "Option_SetHealth")) {
        SetHealth_ResetTHealth();
      }
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_MainMenu.DisplayAt(client, 0, 0);
      }
    }
  }
}

//Handle special days menu
public int SpecialDaysMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  switch(action)
  {
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return;
      }
      
      //Check time in which special day was used
      if (GetTimeSinceRoundStart() >= SpecialDays_GetSecondsToStartDay()) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Too Late", SpecialDays_GetSecondsToStartDay());
        return;
      }
      
      char specialDayName[32];
      menu.GetItem(param2, specialDayName, sizeof(specialDayName));
      
      //Start Special Day based on name
      SpecialDays_StartSpecialDay(specialDayName, true);
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_MainMenu.DisplayAt(client, 0, 0);
      }
    }
  }
}

//Handle beam options menu
public int BeamOptionsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  menu.GetItem(param2, info, sizeof(info));

  switch(action)
  {
    case MenuAction_DrawItem:
    {
      if (StrEqual(info, "Option_BeamParticleStyle")) {
        if (Beams_GetBeamType() != BeamType_Particle)
          return ITEMDRAW_DISABLED;
      }
    }
    
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return 0;
      }
      
      if (StrEqual(info, "Option_BeamType")) {
        g_BeamTypeMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_BeamDuration")) {
        g_BeamDurationMenu.Display(client, MENU_TIME_FOREVER);
      }
      else if (StrEqual(info, "Option_BeamParticleStyle")) {
        g_BeamParticleStyleMenu.Display(client, MENU_TIME_FOREVER);
      }
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_DrawMenu.DisplayAt(client, 0, 0);
      }
    }
  }
  
  return 0;
}

//Handle duration type menu
public int BeamTypeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  char display[64];
  menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
  
  BeamType beamType = view_as<BeamType>(StringToInt(info));

  switch(action)
  {
    case MenuAction_DrawItem:
    {
      if (beamType == Beams_GetBeamType()) {
        return ITEMDRAW_DISABLED;
      }
      else if (beamType == BeamType_Particle) {
        int isVIP = CheckCommandAccess(client, "", FlagToBit(g_VipFlag));
        if (!isVIP)
          return ITEMDRAW_DISABLED;
      }
    }
    
    case MenuAction_DisplayItem:
    {
      if (beamType == Beams_GetBeamType()) {
        char selectedBeamTypeText[64];
        Format(selectedBeamTypeText, sizeof(selectedBeamTypeText), "%s [*]", display);
        return RedrawMenuItem(selectedBeamTypeText);
      }
      else if (beamType == BeamType_Particle) {
        int isVIP = CheckCommandAccess(client, "", FlagToBit(g_VipFlag));
        if (!isVIP) {
          char particleBeamText[64];
          Format(particleBeamText, sizeof(particleBeamText), "Particle Beams (VIP Only)");
          return RedrawMenuItem(particleBeamText);
        }
      }
    }
    
    case MenuAction_Select:
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
      g_BeamTypeMenu.DisplayAt(client, GetMenuSelectionPosition(), 0);
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_BeamOptionsMenu.DisplayAt(client, 0, 0);
      }
    }
  }
  
  return 0;
}

//Handle duration menu
public int BeamDurationMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  char display[64];
  menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

  switch(action)
  {
    case MenuAction_DrawItem:
    {
      if (StringToFloat(info) == Beams_GetBeamDuration())
          return ITEMDRAW_DISABLED;
    }
    
    case MenuAction_DisplayItem:
    {
      if (StringToFloat(info) == Beams_GetBeamDuration()) {
        char selectedDurationText[64];
        Format(selectedDurationText, sizeof(selectedDurationText), "%s [*]", display);
        return RedrawMenuItem(selectedDurationText);
      }
    }
    
    case MenuAction_Select:
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
      g_BeamDurationMenu.DisplayAt(client, GetMenuSelectionPosition(), 0);
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_BeamOptionsMenu.DisplayAt(client, 0, 0);
      }
    }
  }
  
  return 0;
}

//Handle beam particle style
public int BeamParticleStyleMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  char display[64];
  menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

  int particleBeamStyle = StringToInt(info);
  
  switch(action)
  {
    case MenuAction_DrawItem:
    {
      if (particleBeamStyle == ParticleBeams_GetStyle())
        return ITEMDRAW_DISABLED;
    }
    
    case MenuAction_DisplayItem:
    {
      if (particleBeamStyle == ParticleBeams_GetStyle()) {
        char selectedParticleBeamStyleText[64];
        Format(selectedParticleBeamStyleText, sizeof(selectedParticleBeamStyleText), "%s [*]", display);
        return RedrawMenuItem(selectedParticleBeamStyleText);
      }
    }
    
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return 0;
      }
      
      ParticleBeams_SetStyle(particleBeamStyle);
      
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Beam Style Set", display);
      
      //Go back to parent menu
      g_BeamParticleStyleMenu.DisplayAt(client, GetMenuSelectionPosition(), 0);
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_BeamOptionsMenu.DisplayAt(client, 0, 0);
      }
    }
  }
  
  return 0;
}

//Handle colour menu
public int SetColourMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  char info[32];
  char display[64];
  menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
  
  Colour colourCode = view_as<Colour>(StringToInt(info));

  switch(action)
  {
    case MenuAction_DrawItem:
    {
      //Disable currently selected colour
      if (g_Colours_CurrentColourCode == colourCode)
        return ITEMDRAW_DISABLED;
    }
    
    case MenuAction_DisplayItem:
    {
      if (g_Colours_CurrentColourCode == colourCode) {
        char selectedColourText[64];
        Format(selectedColourText, sizeof(selectedColourText), "%s [*]", display);
        return RedrawMenuItem(selectedColourText);
      }
    }
    
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return 0;
      }
      
      //Set colour code
      g_Colours_CurrentColourCode = colourCode;
      
      //Set current colour
      int newColour[4];
      Colours_GetColourFromColourCode(colourCode, newColour);
      Colours_SetCurrentColour(newColour);
      
      //Print message
      if (colourCode == Colour_Red) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "darkred", "red");
       }
      else if (colourCode == Colour_Green) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightgreen", "green");
      }
      else if (colourCode == Colour_Blue) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "blue", "blue");
      }
      else if (colourCode == Colour_Purple) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "purple", "purple");
      }
      else if (colourCode == Colour_Yellow) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "olive", "yellow");
      }
      else if (colourCode == Colour_Cyan) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightblue", "cyan");
      }
      else if (colourCode == Colour_Pink) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "pink");
      }
      else if (colourCode == Colour_Orange) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "orange");
      }
      else if (colourCode == Colour_White) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "white");
      }
      else if (colourCode == Colour_Black) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "black");
      }
      
      g_SetColourMenu.DisplayAt(client, GetMenuSelectionPosition(), 0);
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_DrawMenu.DisplayAt(client, 0, 0);
      }
    }
  }
  
  return 0;
}

//Handle shark menu
public int SharkMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  switch(action)
  {
    case MenuAction_Select:
    {
      //Ensure user is warden
      bool isWarden = view_as<bool>(warden_iswarden(client));
      
      if (!isWarden) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
        return;
      }
      
      char info[32];
      menu.GetItem(param2, info, sizeof(info));
      int target = GetClientOfUserId(StringToInt(info));
      
      Shark_SetShark(target);
      
      g_GameMenu.DisplayAt(client, 0, 0);
    }
    
    case MenuAction_Cancel:
    {
      if (param2 == MenuCancel_ExitBack) {
        //Goto parent menu
        g_GameMenu.DisplayAt(client, 0, 0);
      }
    }
    
    case MenuAction_End:
    {
      delete menu;
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
  return (curTime - g_NewRoundTimeElapsed);
}

stock int GetClientAimPlayer(int client) {
	float vAngles[3];
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	Handle traceRay = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterOnlyPlayers, client);
	if(TR_DidHit(traceRay)) {
		int target = TR_GetEntityIndex(traceRay);
		delete traceRay;
		return (target == 0) ? -1 : target;
	}
	delete traceRay;
	return -1;
}

stock int GetAimOrigin(int client, float hOrigin[3]) 
{
  float vAngles[3], fOrigin[3];
  GetClientEyePosition(client, fOrigin);
  GetClientEyeAngles(client, vAngles);

  Handle traceRay = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
  
  if (TR_DidHit(traceRay)) {
    TR_GetEndPosition(hOrigin, traceRay);
    delete traceRay;
    return 1;
  }

  delete traceRay;
  return -1;
}

public bool TraceEntityFilterOnlyPlayers(int entity, int contentsMask, any data)
{
	return entity > 0 && entity <= MaxClients && entity != data;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, int data)
{
  return (entity > MaxClients || !entity);
}


//Remove all occurances of a value from an array
stock void RemoveAllValuesFromArray(ArrayList array, any item)
{
  int index;
  while ((index = array.FindValue(item)) != -1)
    array.Erase(index);
}


/*********************************
 * Natives
 *********************************/

public int Native_IsSpecialDay(Handle plugin, int numParams)
{
  return SpecialDays_IsSpecialDay();
}

/*********************************
 * Global Forwards
 *********************************/

public void warden_OnWardenCreated(int warden)
{
  //Load preferences from cookies for new warden
  if (AreClientCookiesCached(warden)) {
    char buffer[16];
  
    //g_ColourCookie
    GetClientCookie(warden, g_ColourCookie, buffer, sizeof(buffer));
    
    if (strlen(buffer) == 0) { //Set default values for empty cookie
      Colours_SetCurrentColour(g_Colours_Red);
      g_Colours_CurrentColourCode = Colour_Red; 
    } else {
      Colour colourCode = view_as<Colour>(StringToInt(buffer));
      int newColour[4];
      Colours_GetColourFromColourCode(colourCode, newColour); //get colour from code
      Colours_SetCurrentColour(newColour); //set colour values
      g_Colours_CurrentColourCode = colourCode; //set colour code
    }
    
    //g_BeamTypeCookie
    GetClientCookie(warden, g_BeamTypeCookie, buffer, sizeof(buffer));
    if (strlen(buffer) == 0) //Set default values for empty cookie
      Beams_SetBeamType(BeamType_Colour);
    else
      Beams_SetBeamType(view_as<BeamType>(StringToInt(buffer)));
    
    //g_BeamDurationCookie
    GetClientCookie(warden, g_BeamDurationCookie, buffer, sizeof(buffer));
    if (strlen(buffer) == 0) //Set default values for empty cookie
      Beams_SetDuration(BEAM_DEFAULT_DURATION);
    else
      Beams_SetDuration(StringToFloat(buffer));
    
    //g_BeamParticleStyleCookie
    GetClientCookie(warden, g_BeamParticleStyleCookie, buffer, sizeof(buffer));
    if (strlen(buffer) == 0) //Set default values for empty cookie
      ParticleBeams_SetStyle(DEFAULT_PARTICLEBEAMS_STYLE);
    else
      ParticleBeams_SetStyle(StringToInt(buffer));
  }
  
  //Check beam type status
  int isVIP = CheckCommandAccess(warden, "", FlagToBit(g_VipFlag));
  if (!isVIP && Beams_GetBeamType() == BeamType_Particle) {
    Beams_SetBeamType(BeamType_Colour);
  }
}

public void warden_OnWardenRemoved(int warden)
{
  //Save preferences as cookies
  if (AreClientCookiesCached(warden)) {
    char buffer[16];
    
    //g_ColourCookie
    IntToString(view_as<int>(g_Colours_CurrentColourCode), buffer, sizeof(buffer));
    SetClientCookie(warden, g_ColourCookie, buffer);
    
    //g_BeamTypeCookie
    IntToString(view_as<int>(Beams_GetBeamType()), buffer, sizeof(buffer));
    SetClientCookie(warden, g_BeamTypeCookie, buffer);
    
    //g_BeamDurationCookie
    FloatToString(Beams_GetBeamDuration(), buffer, sizeof(buffer));
    SetClientCookie(warden, g_BeamDurationCookie, buffer);
    
    //g_BeamParticleStyleCookie
    IntToString(ParticleBeams_GetStyle(), buffer, sizeof(buffer));
    SetClientCookie(warden, g_BeamParticleStyleCookie, buffer);
  }
  
  //Remove menus if warden removed
  if (IsClientInGame(warden)) {
    //Kill all menus for warden
    CancelClientMenu(warden);
  }
}