(*
 * Copyright 2021 Mirko Bianco (email: writetomirko@gmail.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *)

unit Fido.Http.Types;

interface

uses
  System.SysUtils,
  System.Rtti,
  REST.Types,

  Spring,
  Spring.Collections;

type
  THttpMethod = (rmUnknown, rmGET, rmPOST, rmPUT, rmPATCH, rmDELETE, rmCOPY, rmHEAD, rmOPTIONS, rmLINK, rmUNLINK, rmPURGE, rmLOCK, rmUNLOCK, rmPROPFIND, rmVIEW);

  TMethodParameterType = (mptUnknown, mptPath, mptForm, mptBody, mptHeader, mptQuery);

  TMimeType = (mtDefault, mtJson, mtHtml, mtImage, mtAll, mtUnknown);

  TEndPointParameter = record
  private
    FIsOut: Boolean;
    FName: string;
    FRestName: string;
    FType: TMethodParameterType;
    FClassType: TClass;
    FTypeInfo: PTypeInfo;
    FIsNullable: Boolean;
    FTypeQualifiedName: string;
  public
    constructor Create(
      const IsOut: Boolean;
      const Name: string;
      const RestName: string;
      const ClassType: TClass;
      const &Type: TMethodParameterType;
      const TypeInfo: PTypeInfo;
      const IsNullable: Boolean;
      const TypeQualifiedName: string);

    property IsOut: Boolean read FIsOut;
    property Name: string read FName;
    property RestName: string read FRestName;
    property ClassType: TClass read FClassType;
    property &Type: TMethodParameterType read FType;
    property TypeInfo: PTypeInfo read FTypeInfo;
    property IsNullable: Boolean read FIsNullable;
    property TypeQualifiedName: string read FTypeQualifiedName;
  end;

  TEndPoint = record
  private
    FInstance: TValue;
    FMethodName: string;
    FPath: string;
    FHttpMethod: THttpMethod;
    FParameters: IList<TEndPointParameter>;
    FConsumes: TArray<TMimeType>;
    FProduces: TArray<TMimeType>;
    FResponseCode: Integer;
    FResponseText: string;
    FPreProcessPipelineSteps: IList<string>;
    FPostProcessPipelineSteps: IList<string>;
  public
    constructor Create(
      const Instance: TValue;
      const MethodName: string;
      const Path: string;
      const HttpMethod: THttpMethod;
      const Parameters: IList<TEndPointParameter>;
      const Consumes: TArray<TMimeType>;
      const Produces: TArray<TMimeType>;
      const ResponseCode: Integer;
      const ResponseText: string;
      const PreProcessPipelineSteps: IList<string>;
      const PostProcessPipelineSteps: IList<string>);


    property Instance: TValue read FInstance;
    property MethodName: string read FMethodName;
    property Path: string read FPath;
    property HttpMethod: THttpMethod read FHttpMethod;
    property Parameters: IList<TEndPointParameter> read FParameters;
    property Consumes: TArray<TMimeType> read FConsumes;
    property Produces: TArray<TMimeType> read FProduces;
    property ResponseCode: Integer read FResponseCode;
    property ResponseText: string read FResponseText;
    property PreProcessPipelineSteps: IList<string> read FPreProcessPipelineSteps;
    property PostProcessPipelineSteps: IList<string> read FPostProcessPipelineSteps;
  end;

  TSSLCertData = record
  strict private
    FSSLRootCertFilePath: string;
    FSSLCertFilePath: string;
    FSSLKeyFilePath: string;
  public
    constructor Create(
      const SSLRootCertFilePath: string;
      const SSLCertFilePath: string;
      const SSLKeyFilePath: string);
    class function CreateEmpty: TSSLCertData; static;

    function IsValid: Boolean;

    function SSLRootCertFilePath: string;
    function SSLCertFilePath: string;
    function SSLKeyFilePath: string;
  end;

const
  SHttpMethod: array[THttpMethod] of string = (
    '',
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'COPY',
    'HEAD',
    'OPTIONS',
    'LINK',
    'UNLINK',
    'PURGE',
    'LOCK',
    'UNLOCK',
    'PROPFIND',
    'VIEW'
  );

  DEFAULTMIME = 'default';

  SMimeType: array[TMimeType] of string = (DEFAULTMIME, CONTENTTYPE_APPLICATION_JSON, CONTENTTYPE_TEXT_HTML, 'image/*', '*/*', '');

implementation

{ TEndPointParameter }

constructor TEndPointParameter.Create(const IsOut: Boolean; const Name, RestName: string; const ClassType: TClass; const &Type: TMethodParameterType; const TypeInfo: PTypeInfo; const IsNullable: Boolean; const TypeQualifiedName: string);
begin
  FIsOut := IsOut;
  FName := Name;
  FRestName := RestName;
  FClassType := ClassType;
  FType := &Type;
  FTypeInfo := TypeInfo;
  FIsNullable := IsNullable;
  FTypeQualifiedName := TypeQualifiedName;
end;

{ TEndPoint }

constructor TEndPoint.Create(
  const Instance: TValue;
  const MethodName: string;
  const Path: string;
  const HttpMethod: THttpMethod;
  const Parameters: IList<TEndPointParameter>;
  const Consumes: TArray<TMimeType>;
  const Produces: TArray<TMimeType>;
  const ResponseCode: Integer;
  const ResponseText: string;
  const PreProcessPipelineSteps: IList<string>;
  const PostProcessPipelineSteps: IList<string>);
begin
  Guard.CheckNotNull(Instance, 'Instance');

  FInstance := Instance;
  FMethodName := MethodName;
  FPath := Path;
  FHttpMethod := HttpMethod;
  FParameters := Parameters;
  FConsumes := Consumes;
  FProduces := Produces;
  FResponseCode := ResponseCode;
  FREsponseText := ResponseText;
  FPreProcessPipelineSteps := PreProcessPipelineSteps;
  FPostProcessPipelineSteps := PostProcessPipelineSteps;
end;

{ TSSLCertData }

constructor TSSLCertData.Create(
  const SSLRootCertFilePath,
        SSLCertFilePath,
        SSLKeyFilePath: string);
begin
  FSSLRootCertFilePath := SSLRootCertFilePath;
  FSSLCertFilePath := SSLCertFilePath;
  FSSLKeyFilePath := SSLKeyFilePath;
end;

class function TSSLCertData.CreateEmpty: TSSLCertData;
begin
  Result.Create('', '', '');
end;

function TSSLCertData.IsValid: Boolean;
begin
  Result := (not SSLRootCertFilePath.IsEmpty) or
    not(SSLCertFilePath.IsEmpty or SSLKeyFilePath.IsEmpty);

  if Result then
    Result := FileExists(SSLRootCertFilePath) or (FileExists(SSLCertFilePath) and FileExists(SSLKeyFilePath));
end;

function TSSLCertData.SSLCertFilePath: string;
begin
  Result := FSSLCertFilePath;
end;

function TSSLCertData.SSLKeyFilePath: string;
begin
  Result := FSSLKeyFilePath;
end;

function TSSLCertData.SSLRootCertFilePath: string;
begin
  Result := FSSLRootCertFilePath;
end;



end.
