/*
* Blind toggle
* Prefix: Blind_
*/

#if defined _wardentools_blind_included
  #endinput
#endif
#define _wardentools_blind_included

#include <wardentools>
#include <cstrike>

static UserMsg s_FadeUserMsgId; //For Blind
static bool s_IsBlind[MAXPLAYERS+1] = false;
static bool s_ShouldBlind = false;

//OnPluginStart
public void Blind_OnPluginStart()
{
  s_FadeUserMsgId = GetUserMessageId("Fade");
  
  HookEvent("player_death", Blind_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", Blind_Reset, EventHookMode_Post);
}

//Player death hook
public Action Blind_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  //Unblind all clients on death who are blind
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (s_IsBlind[client])
    Blind_Unblind(client, 0.0, 0, 0, 0, 0);
}

//OnClientPutInServer
public void Blind_OnClientPutInServer(int client)
{
  s_IsBlind[client] = false;
}

public void Blind_ToggleTeamBlind(int team)
{
  s_ShouldBlind = !s_ShouldBlind; //toggle command

  for (int i = 1; i <= MaxClients ; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == team) {
        if (s_ShouldBlind) {
          Blind_Blind(i);
        } else {
          Blind_Unblind(i);
        }
        
        s_IsBlind[i] = s_ShouldBlind;
      }
    }
  }
  
  char teamName[32];
  if (team == CS_TEAM_T)
    Format(teamName, sizeof(teamName), "prisoners");
  else if (team == CS_TEAM_CT)
    Format(teamName, sizeof(teamName), "guards");
  else
    Format(teamName, sizeof(teamName), "unknown-teams");
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Blind", teamName);
}

//Round pre start
public void Blind_Reset(Event event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Unblind all
    if (s_IsBlind[i]) {
      Blind_Unblind(i);
      s_IsBlind[i] = false;
    }
  }
  
  s_ShouldBlind = false;
}

//Convinient blind helper function
void Blind_Blind(int client, float time = 0.0, int r = 0, int g = 0, int b = 0, int a = 255)
{
  DataPack fadePack;
  CreateDataTimer(time, Blind_FadeClient, fadePack);
  fadePack.WriteCell(client);
  fadePack.WriteCell(r);
  fadePack.WriteCell(g);
  fadePack.WriteCell(b);
  fadePack.WriteCell(a);
}

//Convinient unblind helper function
void Blind_Unblind(int client, float time = 0.0, int r = 0, int g = 0, int b = 0, int a = 0)
{
  DataPack fadePack;
  CreateDataTimer(time, Blind_UnfadeClient, fadePack);
  fadePack.WriteCell(client);
  fadePack.WriteCell(r);
  fadePack.WriteCell(g);
  fadePack.WriteCell(b);
  fadePack.WriteCell(a);
}

public Action Blind_FadeClient(Handle timer, DataPack pack)
{
  pack.Reset();
  
  int targets[2];
  targets[0] = pack.ReadCell();
  
  if (!IsClientConnected(targets[0]) || IsFakeClient(targets[0]))
    return Plugin_Handled;
  
  int color[4];
  color[0] = pack.ReadCell();
  color[1] = pack.ReadCell();
  color[2] = pack.ReadCell();
  color[3] = pack.ReadCell();
  
  int duration = 255;
  int holdtime = 255;
  
  int flags = (0x0002 | 0x0008);
  
  Handle message = StartMessageEx(s_FadeUserMsgId, targets, 1);
  
  if (GetUserMessageType() == UM_Protobuf) {
    Protobuf pb = UserMessageToProtobuf(message);
    pb.SetInt("duration", duration);
    pb.SetInt("hold_time", holdtime);
    pb.SetInt("flags", flags);
    pb.SetColor("clr", color);
  }
  else {
    BfWrite bf = UserMessageToBfWrite(message);
    bf.WriteShort(duration);
    bf.WriteShort(holdtime);
    bf.WriteShort(flags);    
    bf.WriteByte(color[0]);
    bf.WriteByte(color[1]);
    bf.WriteByte(color[2]);
    bf.WriteByte(color[3]);
  }
  
  EndMessage();

  return Plugin_Handled;
}

public Action Blind_UnfadeClient(Handle timer, DataPack pack)
{
  pack.Reset();
  
  int targets[2];
  targets[0] = pack.ReadCell();
  
  if (!IsClientConnected(targets[0]) || IsFakeClient(targets[0]))
    return Plugin_Handled;
  
  int color[4];
  color[0] = pack.ReadCell();
  color[1] = pack.ReadCell();
  color[2] = pack.ReadCell();
  color[3] = pack.ReadCell();
  
  int duration = 1536;
  int holdtime = 1536;
  
  int flags = (0x0001 | 0x0010);

  Handle message = StartMessageEx(s_FadeUserMsgId, targets, 1);
  
  if (GetUserMessageType() == UM_Protobuf) {
    Protobuf pb = UserMessageToProtobuf(message);
    pb.SetInt("duration", duration);
    pb.SetInt("hold_time", holdtime);
    pb.SetInt("flags", flags);
    pb.SetColor("clr", color);
  }
  else {
    BfWrite bf = UserMessageToBfWrite(message);
    bf.WriteShort(duration);
    bf.WriteShort(holdtime);
    bf.WriteShort(flags);    
    bf.WriteByte(color[0]);
    bf.WriteByte(color[1]);
    bf.WriteByte(color[2]);
    bf.WriteByte(color[3]);
  }
  
  EndMessage();

  return Plugin_Handled;
}

//Getters/Setters
public void Blind_SetBlind(int client, bool value)
{
  s_IsBlind[client] = value;
}