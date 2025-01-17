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

unit Fido.DesignPatterns.Decorator.JSonArrayAsReadonlyList;

interface

uses
  System.TypInfo,
  System.JSON,

  Spring.Collections,
  Spring.Collections.Lists,

  Fido.Json.Marshalling;

type
  TJsonArrayAsReadonlyInterfaceList<T: IInterface> = class(TAnonymousReadOnlyList<T>, IReadOnlyList<T>)
  private
    FJsonArray: TJSONArray;
  public
    constructor Create(const JsonArray: TJSONArray); overload;
    constructor Create(const JsonArray: TJSONArray; const TypeInfo: PTypeInfo); overload;

    destructor Destroy; override;
  end;

  TJsonArrayAsReadonlyList<T> = class(TAnonymousReadOnlyList<T>, IReadOnlyList<T>)
  private
    FJsonArray: TJSONArray;
  public
    constructor Create(const JsonArray: TJSONArray); overload;
    
    destructor Destroy; override;
  end;

implementation

{ TJsonArrayAsReadonlyInterfaceList<T> }

constructor TJsonArrayAsReadonlyInterfaceList<T>.Create(const JsonArray: TJSONArray);
begin
  inherited Create(
    function: Integer
    begin
      Result := FJsonArray.Count;
    end,
    function(Index: Integer): T
    begin
      Result := JSONUnmarshaller.To<T>((FJsonArray.Items[Index] as TJSONObject).ToJSON);
    end);
  FJsonArray := TJSONObject.ParseJSONValue(JsonArray.ToJSON) as TJSONArray;
end;

constructor TJsonArrayAsReadonlyInterfaceList<T>.Create(const JsonArray: TJSONArray; const TypeInfo: PTypeInfo);
begin
  inherited Create(
    function: Integer
    begin
      Result := FJsonArray.Count;
    end,
    function(Index: Integer): T
    begin
      Result := JSONUnmarshaller.To((FJsonArray.Items[Index] as TJSONObject).ToJSON, TypeInfo).AsType<T>;
    end);
  FJsonArray := TJSONObject.ParseJSONValue(JsonArray.ToJSON) as TJSONArray;
end;

destructor TJsonArrayAsReadonlyInterfaceList<T>.Destroy;
begin
  FJsonArray.Free;
  inherited;
end;

{ TJsonArrayAsReadonlyList<T> }

constructor TJsonArrayAsReadonlyList<T>.Create(const JsonArray: TJSONArray);
begin
  inherited Create(
    function: Integer
    begin
      Result := FJsonArray.Count;
    end,
    function(Index: Integer): T
    begin
       (FJsonArray.Items[Index] as TJSONValue).TryGetValue<T>(Result);
    end);
  FJsonArray := TJSONObject.ParseJSONValue(JsonArray.ToJSON) as TJSONArray;
end;

destructor TJsonArrayAsReadonlyList<T>.Destroy;
begin
  FJsonArray.Free;
  inherited;
end;

end.
