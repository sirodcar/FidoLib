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

 unit Fido.Gui.Binding;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Classes,
{$IF not declared(FireMonkeyVersion)}
  Vcl.Forms,
  Vcl.Controls,
{$ELSE}
  Fmx.Forms,
  Fmx.Controls,
{$IFEND}

  Fido.Exceptions,
  Fido.DesignPatterns.Observable.Intf,
  Fido.DesignPatterns.Observer.Notification.Intf,
  Fido.Gui.Types,
  Fido.Gui.DesignPatterns.Observer.Anon,
  Fido.Gui.NotifyEvent.Delegated,
  Fido.Gui.Action.Anon,
  Fido.Gui.Binding.Attributes;

type
  EFidoGuiBindingException = class(EFidoException);

  GuiBinding = class
  private
    class procedure InternalObservableSetup<DomainObject: IObservable; Component: TComponent>(
      const Owner: TComponent;
      const Observable: DomainObject;
      const GuiComponent: Component); static;

    class procedure InternalMethodsSetup<Controller: IInterface; Component: TComponent>(
      const Owner: TComponent; const TheController: Controller;
      const GuiComponent: Component); static;
  public
    class procedure SetupObservableToComponent<DomainObject: IObservable; Component: TComponent>(
      const Source: DomainObject;
      const SourceAttributeName: string;
      const Destination: Component;
      const DestinationAttributeName: string); overload; static;

    class procedure SetupComponentToObservable<Component: TComponent; DomainObject: IObservable>(
      const Source: Component;
      const SourceAttributeName: string;
      const SourceEventName: string;
      const Destination: DomainObject;
      const DestinationAttributeName: string); overload; static;

    class procedure SetupBidirectional<DomainObject: IObservable; Component: TComponent>(
      const Source: DomainObject;
      const SourceAttributeName: string;
      const Destination: Component;
      const DestinationAttributeName: string;
      const DestinationEventName: string); overload; static;

    class procedure Setup<DomainObject: IObservable; Component: TComponent>(
      const Observable: DomainObject;
      const GuiComponent: Component); overload; static;

    class procedure MethodsSetup<Controller: IInterface; Component: TComponent>(
      const TheController: Controller;
      const GuiComponent: Component); static;
  end;

implementation

{ GuiBinding }

class procedure GuiBinding.SetupComponentToObservable<Component, DomainObject>(
  const Source: Component;
  const SourceAttributeName: string;
  const SourceEventName: string;
  const Destination: DomainObject;
  const DestinationAttributeName: string);
var
  RttiContext: TRttiContext;
  SourceProperty: TRttiProperty;
  DestinationProperty: TRttiProperty;
  DestinationMethod: TRttiMethod;
begin
  SourceProperty := nil;
  SourceProperty := RttiContext.GetType(Source.ClassType).GetProperty(SourceAttributeName);
  if Assigned(SourceProperty) and not SourceProperty.IsWritable then
    SourceProperty := nil;

  if not Assigned(SourceProperty) then
    raise EFidoGuiBindingException.CreateFmt('Binding error. Property "%s" does not exist for "%s".', [SourceAttributeName, Source.Name]);

  DestinationMethod := nil;
  DestinationProperty := nil;
  DestinationProperty := RttiContext.GetType(TypeInfo(DomainObject)).GetProperty(DestinationAttributeName);
  if Assigned(DestinationProperty) and not DestinationProperty.IsWritable then
    DestinationProperty := nil;
  if not Assigned(DestinationProperty) then
  begin
    if DestinationAttributeName.StartsWith('Set') then
      DestinationMethod := RttiContext.GetType(TypeInfo(DomainObject)).GetMethod(DestinationAttributeName)
    else
      DestinationMethod := RttiContext.GetType(TypeInfo(DomainObject)).GetMethod('Set' + DestinationAttributeName);

    if Assigned(DestinationMethod) and not ((DestinationMethod.MethodKind = mkProcedure) and (Length(DestinationMethod.GetParameters) = 1)) then
      DestinationMethod := nil;
    if not Assigned(DestinationMethod) then
      raise EFidoGuiBindingException.CreateFmt('Binding error. Attribute "%s" does not exist for destination.', [DestinationAttributeName]);
  end;

  DelegatedNotifyEvent.SetUp(
    Source,
    Source as TControl,
    SourceEventName,
    procedure(Sender: TObject)
    begin
      if Assigned(DestinationProperty) then
        DestinationProperty.SetValue(TValue.From<DomainObject>(Destination).AsType<IObserver>, SourceProperty.GetValue(Source as TComponent))
      else if Assigned(DestinationMethod) then
        DestinationMethod.Invoke(TValue.From<DomainObject>(Destination), [SourceProperty.GetValue(Source as TComponent)]);
    end,
    oeetAfter);
end;

class procedure GuiBinding.SetupObservableToComponent<DomainObject, Component>(
  const Source: DomainObject;
  const SourceAttributeName: string;
  const Destination: Component;
  const DestinationAttributeName: string);
var
  RttiContext: TRttiContext;
  DestinationProperty: TRttiProperty;
  SourceProperty: TRttiProperty;
  SourceMethod: TRttiMethod;
begin
  DestinationProperty := nil;
  DestinationProperty := RttiContext.GetType(Destination.ClassType).GetProperty(DestinationAttributeName);
  if Assigned(DestinationProperty) and not DestinationProperty.IsWritable then
    DestinationProperty := nil;

  if not Assigned(DestinationProperty) then
    raise EFidoGuiBindingException.CreateFmt('Binding error. Property "%s" does not exist for "%s".', [DestinationAttributeName, Destination.Name]);

  SourceMethod := nil;
  SourceProperty := nil;
  SourceProperty := RttiContext.GetType(TypeInfo(DomainObject)).GetProperty(SourceAttributeName);
  if Assigned(SourceProperty) and not SourceProperty.IsReadable then
    SourceProperty := nil;
  if not Assigned(SourceProperty) then
  begin
    if SourceAttributeName.StartsWith('Get') then
      SourceMethod := RttiContext.GetType(TypeInfo(DomainObject)).GetMethod(SourceAttributeName)
    else
      SourceMethod := RttiContext.GetType(TypeInfo(DomainObject)).GetMethod('Get' + SourceAttributeName);
    if Assigned(SourceMethod) and not ((SourceMethod.MethodKind = mkFunction) and (Length(SourceMethod.GetParameters) = 0)) then
      SourceMethod := nil;
    if not Assigned(SourceMethod) then
      raise EFidoGuiBindingException.CreateFmt('Binding error. Attribute "%s" does not exist for source.', [SourceAttributeName]);
  end;

  Source.RegisterObserver(
    TAnonGUIObserver<Component>.Create(
      Destination,
      procedure(Dest: Component; Notification: INotification)
      var
        Value: TValue;
      begin
        if Assigned(SourceProperty) then
          Value := SourceProperty.GetValue(TValue.From(Source).AsType<IObserver>)
        else if Assigned(SourceMethod) then
          Value := SourceMethod.Invoke(TValue.From(Source), []);

        if Assigned(DestinationProperty) then
          DestinationProperty.SetValue(Dest as TComponent, Value);

      end));
end;

class procedure GuiBinding.InternalObservableSetup<DomainObject, Component>(
  const Owner: TComponent;
  const Observable: DomainObject;
  const GuiComponent: Component);
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  Attribute: TCustomAttribute;
  Index: Integer;
begin
  Ctx := TRttiContext.Create;
  RttiType := Ctx.GetType(GuiComponent.ClassType);
  for Field in RttiType.GetFields do
    for Attribute in Field.GetAttributes do
    begin
      if Attribute is UnidirectionalToGuiBindingAttribute then
        GuiBinding.SetupObservableToComponent(
          Observable,
          (Attribute as UnidirectionalToGuiBindingAttribute).SourceAttributeName,
          GuiComponent.FindComponent(Field.Name),
          (Attribute as UnidirectionalToGuiBindingAttribute).DestinationAttributeName);
      if Attribute is UnidirectionalToObservableBindingAttribute then
        GuiBinding.SetupComponentToObservable<Component, DomainObject>(
          GuiComponent.FindComponent(Field.Name),
          (Attribute as UnidirectionalToObservableBindingAttribute).SourceAttributeName,
          (Attribute as UnidirectionalToObservableBindingAttribute).SourceEventName,
          Observable,
          (Attribute as UnidirectionalToObservableBindingAttribute).DestinationAttributeName);
      if Attribute is BidirectionalToObservableBindingAttribute then
        GuiBinding.SetupBidirectional(
          Observable,
          (Attribute as BidirectionalToObservableBindingAttribute).SourceAttributeName,
          GuiComponent.FindComponent(Field.Name),
          (Attribute as BidirectionalToObservableBindingAttribute).DestinationAttributeName,
          (Attribute as BidirectionalToObservableBindingAttribute).DestinationEventName);
    end;

  for Index := 0 to GuiComponent.ComponentCount - 1 do
    GuiBinding.InternalObservableSetup(Owner, Observable, GuiComponent.Components[Index]);
end;

class procedure GuiBinding.MethodsSetup<Controller, Component>(
  const TheController: Controller;
  const GuiComponent: Component);
begin
  GuiBinding.InternalMethodsSetup(GuiComponent, TheController, GuiComponent);
end;

class procedure GuiBinding.InternalMethodsSetup<Controller, Component>(
  const Owner: TComponent;
  const TheController: Controller;
  const GuiComponent: Component);
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  Attribute: TCustomAttribute;
  Index: Integer;
begin
  Ctx := TRttiContext.Create;
  RttiType := Ctx.GetType(GuiComponent.ClassType);
  for Field in RttiType.GetFields do
    for Attribute in Field.GetAttributes do
      if Attribute is MethodToActionBindingAttribute then
        AnonAction.Setup(
          Owner,
          GuiComponent.FindComponent(Field.Name) as TControl,
          TheController,
          (Attribute as MethodToActionBindingAttribute).ObservableMethodName,
          (Attribute as MethodToActionBindingAttribute).OriginalEventExecutionType);
end;

class procedure GuiBinding.Setup<DomainObject, Component>(
  const Observable: DomainObject;
  const GuiComponent: Component);
begin
  GuiBinding.InternalObservableSetup(GuiComponent, Observable, GuiComponent);
end;

class procedure GuiBinding.SetupBidirectional<DomainObject, Component>(
  const Source: DomainObject;
  const SourceAttributeName: string;
  const Destination: Component;
  const DestinationAttributeName: string;
  const DestinationEventName: string);
begin
  Guibinding.SetupObservableToComponent<DomainObject, Component>(Source, SourceAttributeName, Destination, DestinationAttributeName);
  Guibinding.SetupComponentToObservable<Component, DomainObject>(Destination, DestinationAttributeName, DestinationEventName, Source, SourceAttributeName);
end;

end.
