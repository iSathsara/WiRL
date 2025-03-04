{******************************************************************************}
{                                                                              }
{       WiRL: RESTful Library for Delphi                                       }
{                                                                              }
{       Copyright (c) 2015-2021 WiRL Team                                      }
{                                                                              }
{       https://github.com/delphi-blocks/WiRL                                  }
{                                                                              }
{******************************************************************************}
unit Server.Forms.Main;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ActnList,
  Vcl.StdCtrls, Vcl.ExtCtrls, System.Actions, Winapi.Windows, Winapi.ShellAPI, System.JSON,
  Xml.xmldom, Xml.XMLIntf, Xml.XMLDoc,

  WiRL.Configuration.Core,
  WiRL.Configuration.Neon,
  WiRL.Configuration.CORS,
  WiRL.Configuration.OpenAPI,
  Neon.Core.Types,
  WiRL.Core.Application,
  WiRL.Core.Engine,
  WiRL.http.FileSystemEngine,
  WiRL.http.Server,
  WiRL.http.Server.Indy,
  OpenAPI.Model.Classes,
  Server.Resources.OpenAPI;

type
  TMainForm = class(TForm)
    TopPanel: TPanel;
    StartButton: TButton;
    StopButton: TButton;
    MainActionList: TActionList;
    actStartServer: TAction;
    actStopServer: TAction;
    PortNumberEdit: TEdit;
    Label1: TLabel;
    Button1: TButton;
    Memo1: TMemo;
    Button2: TButton;
    XMLDocument1: TXMLDocument;
    btnDocumentation: TButton;
    actShowDocumentation: TAction;
    procedure actShowDocumentationExecute(Sender: TObject);
    procedure actShowDocumentationUpdate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure actStartServerExecute(Sender: TObject);
    procedure actStartServerUpdate(Sender: TObject);
    procedure actStopServerExecute(Sender: TObject);
    procedure actStopServerUpdate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private const
    ENG_PATH = 'rest';
    APP_PATH = 'app';
    API_PATH = 'openapi';
  private
    FEngine: TWiRLEngine;
    FRESTServer: TWiRLServer;
    function ConfigureOpenAPIDocument: TOpenAPIDocument;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses
  WiRL.Core.Utils,
  WiRL.Core.Metadata.XMLDoc,
  WiRL.Core.OpenAPI.Resource;

{$R *.dfm}

procedure TMainForm.actShowDocumentationExecute(Sender: TObject);
var
  LUrl: string;
begin
  LUrl := Format('http://localhost:%d/%s/%s/%s/', [FRESTServer.Port, ENG_PATH, APP_PATH, API_PATH]);
  ShellExecute(Handle, 'open', PChar(LUrl), '', '', SW_NORMAL);
end;

procedure TMainForm.actShowDocumentationUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := Assigned(FRESTServer) and FRESTServer.Active;
end;

procedure TMainForm.Button1Click(Sender: TObject);
var
  LContext: TWiRLXMLDocContext;
  LApp: TWiRLApplication;
begin
  LApp := FEngine.GetApplicationByName('demo');
  LContext.Proxy := LApp.Proxy;
  LContext.XMLDocFolder := TWiRLTemplatePaths.Render('{AppPath}\..\..\Docs');
  TWiRLProxyEngineXMLDoc.Process(LContext);
end;

procedure TMainForm.Button2Click(Sender: TObject);
var
  LXMLDoc: TWiRLProxyEngineXMLDoc;
  LContext: TWiRLXMLDocContext;
  LApp: TWiRLApplication;
var
  LDoc: IXMLDocument;
  //LDevNotes, LNodeClass: IXMLNode;
begin
  LApp := FEngine.GetApplicationByName('demo');
  LContext.Proxy := LApp.Proxy;
  LContext.XMLDocFolder := TWiRLTemplatePaths.Render('{AppPath}\..\..\Docs');

  LXMLDoc := TWiRLProxyEngineXMLDoc.Create(LContext);
  try
    LDoc := LXMLDoc.LoadXMLUnit('Server.Resources.Demo');
    //LNodeClass :=
    //Memo1.Lines.Text := LXMLDoc.FindClassWithAttribute(LDoc.DocumentElement, 'TParametersResource');
  finally
    LXMLDoc.Free;
  end;
end;

function TMainForm.ConfigureOpenAPIDocument: TOpenAPIDocument;
var
  LExtensionObject: TJSONObject;
begin
  Result := TOpenAPIDocument.Create(TOpenAPIVersion.v303);

  Result.Info.TermsOfService := 'http://swagger.io/terms/';
  Result.Info.Title := 'WiRL Swagger Integration Demo';
  Result.Info.Version := '1.0.2';
  Result.Info.Description := 'This is a **demo API** to test [WiRL](https://github.com/delphi-blocks/WiRL) OpenAPI documentation features';
  Result.Info.Contact.Name := 'Paolo Rossi';
  Result.Info.Contact.Email := 'paolo@mail.it';
  Result.Info.License.Name := 'Apache 2.0';
  Result.Info.License.Url :=  'http://www.apache.org/licenses/LICENSE-2.0.html';
  Result.AddServer('http://localhost:8080/rest/app', 'Testing Server');
  Result.AddServer('https://api.example.com/rest/app', 'Production Server');

  // Shows how to use Extensions (for ReDoc UI)
  LExtensionObject := TJSONObject.Create;
  LExtensionObject.AddPair('url', 'http://localhost:8080/rest/app/openapi/api-logo.png');
  LExtensionObject.AddPair('backgroundColor', '#FFFFFF');
  LExtensionObject.AddPair('altText', 'API Logo');
  Result.Info.Extensions.AddPair('x-logo', LExtensionObject);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FRESTServer.Free;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  actStopServer.Execute;
end;

/// <summary>
/// Bla *bla* bla
/// </summary>
procedure TMainForm.FormCreate(Sender: TObject);
var
  LDocument: TOpenAPIDocument;
begin
  FRESTServer := TWiRLServer.Create(Self);

  LDocument := ConfigureOpenAPIDocument;

  FEngine :=
    FRESTServer.AddEngine<TWiRLEngine>(ENG_PATH)
      .SetEngineName('RESTEngine');

  FEngine.AddApplication(APP_PATH)
      .SetAppName('demo')
      // Test for namespaces
      .SetResources('Server.Resources.Demo.*')
      .SetResources('Server.Resources.Customer.*')
      .SetFilters('*')

      .Plugin.Configure<IWiRLConfigurationNeon>
        .SetUseUTCDate(True)
        .SetMemberCase(TNeonCase.CamelCase)
      .ApplyConfig

      .Plugin.Configure<IWiRLConfigurationCORS>
        .SetOrigin('*')
        .SetMethods('GET,POST,PUT,DELETE')
        .SetHeaders('Content-Type,Authorization')
      .ApplyConfig

      .Plugin.Configure<IWiRLConfigurationOpenAPI>
        .SetOpenAPIResource(TDocumentationResource)
        .SetXMLDocFolder('{AppPath}\..\..\Docs')
        .SetGUIDocFolder('{AppPath}\..\..\UI')
        //.SetGUIDocFolder('{AppPath}\..\..\ReDoc')
        // Set the OpenAPI document
        .SetAPILogo('api-logo.png')
        .SetAPIDocument(LDocument)
      .ApplyConfig
  ;

  actStartServer.Execute;
end;

procedure TMainForm.actStartServerExecute(Sender: TObject);
begin
  FRESTServer.Port := StrToIntDef(PortNumberEdit.Text, 8080);
  if not FRESTServer.Active then
    FRESTServer.Active := True;
end;

procedure TMainForm.actStartServerUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := not Assigned(FRESTServer) or not FRESTServer.Active;
end;

procedure TMainForm.actStopServerExecute(Sender: TObject);
begin
  FRESTServer.Active := False;
end;

procedure TMainForm.actStopServerUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := Assigned(FRESTServer) and FRESTServer.Active;
end;

end.
