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

unit Fido.Mappers;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Json,
  System.TypInfo,

  Spring,
  Spring.Collections,

  Fido.Exceptions;

type
  EFidoMappingException = class(EFidoException);

  ///  This is a tool (hence the name without the T at the beginning)
  ///  The tool allows to register and use mappers
  Mappers = class
  strict private type
    ///  This class manages/contains the Mappers.
    ///  It is useless from the outside and it is managed by the Mappers<TA, TB> tool.
    TMappers = class
    strict private type
      TValueMapProc = TProc<TValue, TValue>;
    const
      GETTER_PREFIX = 'GET';
      SETTER_PREFIX = 'SET';
    var
      FLock: IReadWriteSync;
      FMappersMap: IDictionary<PTypeInfo, IDictionary<PTypeInfo, TValueMapProc>>;

      function TryGetGetterMethodPropName(const RttiMeth: TRttiMethod; out PropertyName: string): Boolean;
      function TryGetSetterMethodPropName(const RttiMeth: TRttiMethod; out PropertyName: string): Boolean;
      function GetInstanceValues<TA>(const Instance: TA): IDictionary<string, TValue>;
      function SetInstanceValues<TB>(const Instance: TB; const Values: IDictionary<string, TValue>): Boolean;
    private
      procedure Clear;
      function ConvertMapProc<TA, TB>(const MapProc: TProc<TA, TB>): TValueMapProc;
      procedure RegisterMapper<TA, TB>(const MapProc: TProc<TA, TB>);
      procedure Map<TA, TB>(const Source: TA; const Dest: TB);
      function TryAutoMap<TA, TB>(const Source: TA; const Dest: TB): Boolean;
      constructor Create;
    end;

    class var
      FMappers: TMappers;
    class function GetMappers: TMappers; static;
  public
    class destructor Destroy; static;

    class procedure ClearMappers; static;
    class procedure RegisterMapper<TA, TB>(const MapProc: TProc<TA, TB>); static;
    class procedure Map<TA, TB>(const Source: TA; const Dest: TB); static;
  end;

implementation

{ Mappers.TMappers }

constructor Mappers.TMappers.Create;
begin
  inherited;
  FLock := TMREWSync.Create;
  FMappersMap := Spring.Collections.TCollections.CreateDictionary<PTypeInfo, IDictionary<PTypeInfo, TValueMapProc>>;
end;

procedure Mappers.TMappers.Map<TA, TB>(const Source: TA; const Dest: TB);
var
  SourceTypeInfo: PTypeInfo;
  DestTypeInfo: PTypeInfo;
  Map: IDictionary<PTypeInfo, TValueMapProc>;
  ValueMapProc: TValueMapProc;
begin
  SourceTypeInfo := TypeInfo(TA);
  DestTypeInfo := TypeInfo(TB);

  FLock.BeginRead;
  try
    if FMappersMap.TryGetValue(SourceTypeInfo, Map) and
       Map.TryGetValue(DestTypeInfo, ValueMapProc) then
      ValueMapProc(TValue.From<TA>(Source), TValue.From<TB>(Dest))
    else if not TryAutoMap<TA, TB>(Source, Dest) then
      raise EFidoMappingException.CreateFmt('Types "%s" and/or "%s" are not registered as mapping types and cannot automap.', [SourceTypeInfo.Name, DestTypeInfo.Name]);
  finally
    FLock.EndRead;
  end;
end;

function Mappers.TMappers.TryGetGetterMethodPropName(const RttiMeth: TRttiMethod;
                                 out PropertyName: string): Boolean;
begin
  PropertyName := RttiMeth.Name.ToUpper;
  if RttiMeth.Name.ToUpper.StartsWith(GETTER_PREFIX) then
    PropertyName := RttiMeth.Name.Remove(0, Length(GETTER_PREFIX)).ToUpper;

  Result := not PropertyName.IsEmpty;
end;

function Mappers.TMappers.TryGetSetterMethodPropName(const RttiMeth: TRttiMethod;
                                 out PropertyName: string): Boolean;
begin
  PropertyName := RttiMeth.Name;
  if RttiMeth.Name.ToUpper.StartsWith(SETTER_PREFIX) then
    PropertyName := RttiMeth.Name.Remove(0, Length(SETTER_PREFIX)).ToUpper;

  Result := not PropertyName.IsEmpty;
end;

function Mappers.TMappers.GetInstanceValues<TA>(const Instance: TA): IDictionary<string, TValue>;
var
  Context: Shared<TRttiContext>;
  RttiType: TRttiType;
  RttiMeth: TRttiMethod;
  RttiProp: TRttiProperty;
  PropertyName: string;
  InstanceValue: TValue;
begin
  InstanceValue := TValue.From<TA>(Instance);
  Result := TCollections.CreateDictionary<string, TValue>;
  Context := TRttiContext.Create;
  RttiType := Context.Value.GetType(TypeInfo(TA));

  if Length(RttiType.GetProperties) <> 0 then
    for RttiProp in RttiType.GetProperties do
      if (RttiProp.Visibility = mvPublished) and
         RttiProp.IsReadable then
        Result.AddOrSetValue(RttiProp.Name.ToUpper, RttiProp.GetValue(InstanceValue.AsPointer))
  else
    for RttiMeth in RttiType.GetMethods do
      if (RttiMeth.Visibility = mvPublished) and
         (RttiMeth.MethodKind = mkFunction) and
         (Length(RttiMeth.GetParameters) = 0) and
         TryGetGetterMethodPropName(RttiMeth, PropertyName) then
        Result.AddOrSetValue(PropertyName, RttiMeth.Invoke(InstanceValue, []));
end;

function Mappers.TMappers.SetInstanceValues<TB>(const Instance: TB; const Values: IDictionary<string, TValue>): Boolean;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  RttiMeth: TRttiMethod;
  RttiProp: TRttiProperty;
  PropertyName: string;
  Value: TValue;
  InstanceValue: TValue;
begin
  InstanceValue := TValue.From<TB>(Instance);
  Result := False;
  Context := TRttiContext.Create();
  try
    RttiType := Context.GetType(TypeInfo(TB));
    if Length(RttiType.GetProperties) <> 0 then
    begin
      for RttiProp in RttiType.GetProperties do
        if (RttiProp.Visibility = mvPublished) and
           RttiProp.IsWritable and
           Values.TryGetValue(RttiProp.Name.ToUpper, Value) then
          RttiProp.SetValue(InstanceValue.AsPointer, Value);
    end
    else
      for RttiMeth in RttiType.GetMethods do
        if (RttiMeth.Visibility = mvPublished) and
           (RttiMeth.MethodKind = mkProcedure) and
           (Length(RttiMeth.GetParameters) = 1) and
           TryGetSetterMethodPropName(RttiMeth, PropertyName) and
           Values.TryGetValue(PropertyName, Value) then
          RttiMeth.Invoke(InstanceValue, [Value]);

    Result := True;
  except
    // a pokemon try/except so that if any conversion error happens the result is False
  end;
end;

function Mappers.TMappers.TryAutoMap<TA, TB>(const Source: TA; const Dest: TB): Boolean;
begin
  Result := SetInstanceValues<TB>(Dest, GetInstanceValues<TA>(Source));
end;

procedure Mappers.TMappers.Clear;
begin
  FLock.BeginWrite;
  try
    FMappersMap.Clear;
  finally
    FLock.EndWrite;
  end;
end;

function Mappers.TMappers.ConvertMapProc<TA, TB>(const MapProc: TProc<TA, TB>): TValueMapProc;
begin
  Result := procedure(SourceValue: TValue; DestValue: TValue)
            var
              GenericSource: TA;
              GenericDest: TB;
            begin
               if not SourceValue.TryAsType<TA>(GenericSource) then
                 raise EFidoMappingException.CreateFmt('Cannot resolve type "%s"', [SourceValue.TypeInfo.Name]);
               if not DestValue.TryAsType<TB>(GenericDest) then
                 raise EFidoMappingException.CreateFmt('Cannot resolve type "%s"', [DestValue.TypeInfo.Name]);
              MapProc(GenericSource, GenericDest);
            end;
end;

procedure Mappers.TMappers.RegisterMapper<TA, TB>(const MapProc: TProc<TA, TB>);
var
  Map: IDictionary<PTypeInfo, TValueMapProc>;
  SourceTypeInfo: PTypeInfo;
  DestTypeInfo: PTypeInfo;
  ValueMapProc: TValueMapProc;
begin
  SourceTypeInfo := TypeInfo(TA);
  DestTypeInfo := TypeInfo(TB);
  FLock.BeginWrite;
  try
    if not FMappersMap.TryGetValue(SourceTypeInfo, Map) then
      Map := Spring.Collections.TCollections.CreateDictionary<PTypeInfo, TValueMapProc>;

    ValueMapProc := ConvertMapProc<TA, TB>(MapProc);

    Map.AddOrSetValue(DestTypeInfo, ValueMapProc);
    FMappersMap.AddOrSetValue(SourceTypeInfo, Map);
  finally
    FLock.EndWrite;
  end;
end;

{ Mappers }

class procedure Mappers.ClearMappers;
begin
  if not Assigned(FMappers) then
    Exit;
  FMappers.Clear;
end;

class destructor Mappers.Destroy;
begin
  if Assigned(FMappers) then
    FMappers.Free;
end;

class function Mappers.GetMappers: TMappers;
begin
  if not Assigned(FMappers) then
    FMappers := TMappers.Create;
  Result := FMappers;
end;

class procedure Mappers.Map<TA, TB>(const Source: TA; const Dest: TB);
begin
  GetMappers.Map<TA, TB>(Source, Dest);
end;

class procedure Mappers.RegisterMapper<TA, TB>(const MapProc: TProc<TA, TB>);
begin
  GetMappers.RegisterMapper<TA, TB>(MapProc);
end;

end.

