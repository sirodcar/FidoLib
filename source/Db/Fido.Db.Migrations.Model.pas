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

 unit Fido.Db.Migrations.Model;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,

  Spring,
  Spring.Collections,

  Fido.Db.ScriptRunner.Intf,
  Fido.Db.Migrations.Repository.Intf,
  Fido.Db.Migrations.Model.Intf;

type
  TDatabaseMigrationsModel = class(TInterfacedObject, IDatabaseMigrationsModel)
  private
    FScriptsFolder: string;
    FScriptRunner: IDatabaseScriptRunner;
    FDatabaseMigrationsRepository: IDatabaseMigrationsRepository;
  public
    constructor Create(
      const ScriptRunner: IDatabaseScriptRunner;
      const DatabaseMigrationsRepository: IDatabaseMigrationsRepository;
      const ScriptsFolder: string);

    procedure Run;
  end;

implementation

{ TDatabaseMigrationsModel }

constructor TDatabaseMigrationsModel.Create(
  const ScriptRunner: IDatabaseScriptRunner;
  const DatabaseMigrationsRepository: IDatabaseMigrationsRepository;
  const ScriptsFolder: string);
begin
  inherited Create;
  Guard.CheckNotNull(ScriptRunner, 'ScriptRunner');
  Guard.CheckNotNull(DatabaseMigrationsRepository, 'DatabaseMigrationsRepository');
  Guard.CheckTrue(not ScriptsFolder.IsEmpty, 'ScriptsFolder cannot be empty');
  FScriptRunner := ScriptRunner;
  FDatabaseMigrationsRepository := DatabaseMigrationsRepository;
  FScriptsFolder := ScriptsFolder;
end;

procedure TDatabaseMigrationsModel.Run;
var
  AlreadyRunMigrations: ISet<string>;
  FoundMigrations: IList<string>;
  ToRunMigrations: IList<string>;
  Migration: string;
  FileName: string;
  Script: Shared<TStringList>;
begin
  AlreadyRunMigrations := FDatabaseMigrationsRepository.GetOldDBMigrations;
  FoundMigrations := TCollections.CreateList<string>(TStringComparer.OrdinalIgnoreCase);
  FoundMigrations.InsertRange(0, TDirectory.GetFiles(FScriptsFolder, '*.sql', TSearchOption.soTopDirectoryOnly));
  ToRunMigrations := TCollections.CreateList<string>(TStringComparer.OrdinalIgnoreCase);

  for Migration in FoundMigrations do
  begin
    FileName := ExtractFileName(Migration);
    if not AlreadyRunMigrations.Contains(FileName) then
      ToRunMigrations.Add(Migration);
  end;

  for Migration in ToRunMigrations do
  begin
    Script := TStringList.Create;
    Script.Value.LoadFromFile(Migration);
    FScriptRunner.Execute(Script);
    FDatabaseMigrationsRepository.SaveDBMigration(ExtractFileName(Migration));
  end;
end;

end.
