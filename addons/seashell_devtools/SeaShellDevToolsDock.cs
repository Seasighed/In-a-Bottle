using System.Diagnostics;
using System.Text;
using System.Text.Json;
using Godot;

namespace SeaShellDevTools;

[Tool]
public partial class SeaShellDevToolsDock : EditorDock
{
    private const string ActiveProfileSettingKey = "seashell_devtools/active_profile_path";
    private const string TargetProjectPathSettingKey = "seashell_devtools/target_project_path";
    private const string LegacyLinkTargetProjectSettingKey = "seashell_devtools/link_target_project_path";
    private const string BuildEditorExecutablePathSettingKey = "seashell_devtools/build_editor_executable_path";

    private EditorPlugin? _plugin;
    private BuildProfileStore? _profileStore;
    private readonly BuildRunner _runner = new();

    private IReadOnlyList<BuildProfileRecord> _profiles = Array.Empty<BuildProfileRecord>();
    private ExportPresetCatalog? _presetCatalog;
    private bool _suppressUiEvents;
    private long _visibleRunId = -1;
    private long _lastAutoOpenedRunId = -1;
    private bool _isLinkCommandRunning;

    private OptionButton _profileSelector = null!;
    private Button _duplicateProfileButton = null!;
    private Button _deleteProfileButton = null!;
    private Button _openOutputFolderButton = null!;
    private OptionButton _presetSelector = null!;
    private OptionButton _buildModeSelector = null!;
    private LineEdit _displayNameEdit = null!;
    private LineEdit _outputDirectoryEdit = null!;
    private LineEdit _fileNameEdit = null!;
    private CheckBox _prebuildCheckBox = null!;
    private CheckBox _verboseCheckBox = null!;
    private CheckBox _openFolderOnSuccessCheckBox = null!;
    private Label _presetHintLabel = null!;
    private Label _profileStatusLabel = null!;
    private ProgressBar _progressBar = null!;
    private Label _progressLabel = null!;
    private Label _stepLabel = null!;
    private Label _detailLabel = null!;
    private Label _elapsedLabel = null!;
    private RichTextLabel _logView = null!;
    private Button _buildButton = null!;
    private Button _abortButton = null!;
    private ConfirmationDialog _deleteDialog = null!;
    private LineEdit _linkTargetPathEdit = null!;
    private Label _linkTargetStatusLabel = null!;
    private LineEdit _buildEditorPathEdit = null!;
    private Label _buildEditorStatusLabel = null!;
    private CheckBox _linkEnablePluginCheckBox = null!;
    private CheckBox _linkBuildSolutionsCheckBox = null!;
    private TextEdit _linkCommandPreview = null!;
    private Button _browseLinkTargetButton = null!;
    private Button _browseBuildEditorButton = null!;
    private Button _copyLinkCommandButton = null!;
    private Button _runLinkCommandButton = null!;
    private Button _rememberLinkTargetButton = null!;
    private FileDialog _linkProjectDialog = null!;
    private FileDialog _buildEditorDialog = null!;

    public void Initialize(EditorPlugin plugin)
    {
        _plugin = plugin;
        _profileStore = new BuildProfileStore(ProjectSettings.GlobalizePath("res://"));
        Name = "Sea Shell DevTools";
        Title = "Sea Shell DevTools";
        LayoutKey = "SeaShellDevToolsDock";
        IconName = "Tools";
        DefaultSlot = DockSlot.Bottom;
        AvailableLayouts = DockLayout.Horizontal | DockLayout.Floating;
    }

    public override void _Ready()
    {
        BuildUi();
        RefreshData();
        SetProcess(true);
    }

    public override void _Process(double delta)
    {
        DrainRunnerLogs();
        RefreshRunStatus();
    }

    public void OpenDock()
    {
        MakeVisible();
    }

    public void BuildActiveProfileFromMenu()
    {
        MakeVisible();
        StartBuild();
    }

    private void BuildUi()
    {
        var root = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        AddChild(root);

        var toolbar = new HBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        root.AddChild(toolbar);

        toolbar.AddChild(new Label
        {
            Text = "Active Profile",
            VerticalAlignment = VerticalAlignment.Center,
        });

        _profileSelector = new OptionButton
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        _profileSelector.ItemSelected += OnProfileSelected;
        toolbar.AddChild(_profileSelector);

        toolbar.AddChild(CreateButton("New", CreateProfile));
        _duplicateProfileButton = CreateButton("Duplicate", DuplicateProfile);
        toolbar.AddChild(_duplicateProfileButton);
        _deleteProfileButton = CreateButton("Delete", ConfirmDeleteProfile);
        toolbar.AddChild(_deleteProfileButton);
        toolbar.AddChild(CreateButton("Refresh", RefreshData));
        toolbar.AddChild(CreateButton("Profiles Folder", OpenProfilesFolder));

        _buildButton = CreateButton("Build", StartBuild);
        toolbar.AddChild(_buildButton);
        _abortButton = CreateButton("Abort", AbortBuild);
        _abortButton.Visible = false;
        toolbar.AddChild(_abortButton);
        _openOutputFolderButton = CreateButton("Open Output", OpenConfiguredOutputFolder);
        toolbar.AddChild(_openOutputFolderButton);

        _profileStatusLabel = new Label
        {
            Text = "Profiles are stored in res://devtools/build_profiles and committed with the repo.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
        };
        root.AddChild(_profileStatusLabel);

        var progressPanel = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        root.AddChild(progressPanel);

        var progressRow = new HBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        progressPanel.AddChild(progressRow);

        _progressBar = new ProgressBar
        {
            MinValue = 0,
            MaxValue = 100,
            Value = 0,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        progressRow.AddChild(_progressBar);

        _progressLabel = new Label
        {
            Text = "0% estimate",
            VerticalAlignment = VerticalAlignment.Center,
        };
        progressRow.AddChild(_progressLabel);

        _stepLabel = new Label
        {
            Text = "Step: Idle",
        };
        progressPanel.AddChild(_stepLabel);

        _detailLabel = new Label
        {
            Text = "The build log is authoritative. Percent complete is a phase-weighted estimate.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
        };
        progressPanel.AddChild(_detailLabel);

        _elapsedLabel = new Label
        {
            Text = "Elapsed: 00:00:00",
        };
        progressPanel.AddChild(_elapsedLabel);

        var split = new HSplitContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        root.AddChild(split);

        split.AddChild(BuildSettingsPanel());
        split.AddChild(BuildLogPanel());

        _deleteDialog = new ConfirmationDialog
        {
            DialogText = "Delete the selected build profile? This removes the .tres file from res://devtools/build_profiles.",
        };
        _deleteDialog.Confirmed += DeleteSelectedProfile;
        AddChild(_deleteDialog);
    }

    private Control BuildSettingsPanel()
    {
        var panel = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
            CustomMinimumSize = new Vector2(460, 0),
        };

        panel.AddChild(new Label
        {
            Text = "Profile Settings",
            ThemeTypeVariation = "HeaderSmall",
        });

        _presetHintLabel = new Label
        {
            Text = "Build presets come from export_presets.cfg. Manage their platform-specific settings in Project > Export.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
        };
        panel.AddChild(_presetHintLabel);

        var grid = new GridContainer
        {
            Columns = 2,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        panel.AddChild(grid);

        AddField(grid, "Display Name", out _displayNameEdit);
        _displayNameEdit.TextSubmitted += _ => SaveEditedTextFields();
        _displayNameEdit.FocusExited += SaveEditedTextFields;

        grid.AddChild(new Label { Text = "Export Preset" });
        _presetSelector = new OptionButton { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        _presetSelector.ItemSelected += OnPresetSelected;
        grid.AddChild(_presetSelector);

        grid.AddChild(new Label { Text = "Build Mode" });
        _buildModeSelector = new OptionButton { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        _buildModeSelector.AddItem("Release", (int)BuildProfileBuildMode.Release);
        _buildModeSelector.AddItem("Debug", (int)BuildProfileBuildMode.Debug);
        _buildModeSelector.ItemSelected += _ => SaveChoiceFields();
        grid.AddChild(_buildModeSelector);

        AddField(grid, "Output Directory", out _outputDirectoryEdit);
        _outputDirectoryEdit.TextSubmitted += _ => SaveEditedTextFields();
        _outputDirectoryEdit.FocusExited += SaveEditedTextFields;

        AddField(grid, "Output File", out _fileNameEdit);
        _fileNameEdit.TextSubmitted += _ => SaveEditedTextFields();
        _fileNameEdit.FocusExited += SaveEditedTextFields;

        panel.AddChild(CreateCheckBox("Pre-build C# solution", out _prebuildCheckBox, SaveChoiceFields));
        panel.AddChild(CreateCheckBox("Verbose Godot child-process logs", out _verboseCheckBox, SaveChoiceFields));
        panel.AddChild(CreateCheckBox("Open output folder on success", out _openFolderOnSuccessCheckBox, SaveChoiceFields));
        panel.AddChild(BuildLinkPanel());

        return panel;
    }

    private Control BuildLogPanel()
    {
        var panel = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };

        panel.AddChild(new Label
        {
            Text = "Run Log",
            ThemeTypeVariation = "HeaderSmall",
        });

        _logView = new RichTextLabel
        {
            BbcodeEnabled = true,
            ScrollFollowing = true,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
            SelectionEnabled = true,
        };
        panel.AddChild(_logView);
        return panel;
    }

    private static Button CreateButton(string text, Action action)
    {
        var button = new Button { Text = text };
        button.Pressed += action;
        return button;
    }

    private Control CreateCheckBox(string text, out CheckBox checkBox, Action saveAction)
    {
        checkBox = new CheckBox
        {
            Text = text,
        };
        checkBox.Toggled += _ => saveAction();
        return checkBox;
    }

    private Control BuildLinkPanel()
    {
        var panel = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };

        panel.AddChild(new HSeparator());
        panel.AddChild(new Label
        {
            Text = "Target Project",
            ThemeTypeVariation = "HeaderSmall",
        });

        panel.AddChild(new Label
        {
            Text = "Choose or paste another local Godot project path. Builds use that target project's export presets and output paths. Leave this blank to build the current host project. You can also link the addon into that target project for the existing C# consumer workflow.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
        });

        var pathRow = new HBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        panel.AddChild(pathRow);

        _linkTargetPathEdit = new LineEdit
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            PlaceholderText = @"X:\Data\Projects\MyGame",
        };
        _linkTargetPathEdit.TextChanged += _ => OnLinkTargetPathChanged();
        _linkTargetPathEdit.TextSubmitted += _ => UpdateLinkCommandPreview();
        pathRow.AddChild(_linkTargetPathEdit);

        _browseLinkTargetButton = CreateButton("Browse...", BrowseForLinkTarget);
        pathRow.AddChild(_browseLinkTargetButton);

        _rememberLinkTargetButton = CreateButton("Remember", RememberLinkTargetProject);
        pathRow.AddChild(_rememberLinkTargetButton);

        _linkTargetStatusLabel = new Label
        {
            Text = "Choose a Godot project folder or paste any path inside a Godot project.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
        };
        panel.AddChild(_linkTargetStatusLabel);

        panel.AddChild(new Label
        {
            Text = "Build Editor Override",
        });

        var editorRow = new HBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        panel.AddChild(editorRow);

        _buildEditorPathEdit = new LineEdit
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            PlaceholderText = "Blank = use the current Godot editor executable",
        };
        _buildEditorPathEdit.TextChanged += _ => OnBuildEditorPathChanged();
        editorRow.AddChild(_buildEditorPathEdit);

        _browseBuildEditorButton = CreateButton("Browse...", BrowseForBuildEditor);
        editorRow.AddChild(_browseBuildEditorButton);

        _buildEditorStatusLabel = new Label
        {
            Text = "Builds default to the current editor executable. Use an override when an external target needs a different Godot editor/template install.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
        };
        panel.AddChild(_buildEditorStatusLabel);

        panel.AddChild(new HSeparator());
        panel.AddChild(new Label
        {
            Text = "Link Addon Into Target Project",
            ThemeTypeVariation = "HeaderSmall",
        });

        panel.AddChild(CreateCheckBox("Enable plugin in target project", out _linkEnablePluginCheckBox, UpdateLinkCommandPreview));
        panel.AddChild(CreateCheckBox("Build target C# solution after linking", out _linkBuildSolutionsCheckBox, UpdateLinkCommandPreview));

        panel.AddChild(new Label
        {
            Text = "Generated Command",
        });

        _linkCommandPreview = new TextEdit
        {
            Editable = false,
            ContextMenuEnabled = true,
            CustomMinimumSize = new Vector2(0, 84),
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        panel.AddChild(_linkCommandPreview);
        _linkEnablePluginCheckBox.SetPressedNoSignal(true);

        var actionsRow = new HBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        panel.AddChild(actionsRow);

        _copyLinkCommandButton = CreateButton("Copy Command", CopyLinkCommand);
        actionsRow.AddChild(_copyLinkCommandButton);

        _runLinkCommandButton = CreateButton("Link Now", RunLinkCommandNow);
        actionsRow.AddChild(_runLinkCommandButton);

        actionsRow.AddChild(CreateButton("Open Tools Folder", OpenToolsFolder));

        _linkProjectDialog = new FileDialog
        {
            Title = "Choose Target Godot Project Folder",
            Access = FileDialog.AccessEnum.Filesystem,
            FileMode = FileDialog.FileModeEnum.OpenDir,
            Size = new Vector2I(920, 620),
        };
        _linkProjectDialog.DirSelected += OnLinkProjectDirectorySelected;
        AddChild(_linkProjectDialog);

        _buildEditorDialog = new FileDialog
        {
            Title = "Choose Godot Editor Executable",
            Access = FileDialog.AccessEnum.Filesystem,
            FileMode = FileDialog.FileModeEnum.OpenFile,
            Size = new Vector2I(920, 620),
        };
        _buildEditorDialog.FileSelected += OnBuildEditorFileSelected;
        AddChild(_buildEditorDialog);

        return panel;
    }

    private static void AddField(GridContainer grid, string label, out LineEdit lineEdit)
    {
        grid.AddChild(new Label { Text = label });
        lineEdit = new LineEdit
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        grid.AddChild(lineEdit);
    }

    private void RefreshData()
    {
        if (_profileStore is null)
        {
            return;
        }

        LoadStoredTargetProjectPath();
        LoadStoredBuildEditorPath();
        _presetCatalog = LoadConfiguredTargetPresetCatalog();
        _profiles = _profileStore.LoadProfiles();

        var storedPath = GetStoredActiveProfilePath();
        if (_profiles.Count == 0)
        {
            var firstPreset = GetPreferredDefaultPreset();
            var defaultProfileName = BuildProfileNameForPreset(firstPreset, isFirstProfile: true);
            _profileStore.CreateProfile(defaultProfileName, firstPreset);
            _profiles = _profileStore.LoadProfiles();
        }

        RebuildProfileSelector(storedPath);
        RebuildPresetSelector();
        LoadSelectedProfileIntoForm();
        UpdateLinkCommandPreview();
        UpdateBuildEditorStatus();
        RefreshRunStatus();
        UpdateActionAvailability();
    }

    private void RebuildProfileSelector(string? preferredPath)
    {
        _suppressUiEvents = true;
        _profileSelector.Clear();

        var selectedIndex = -1;
        for (var i = 0; i < _profiles.Count; i += 1)
        {
            var record = _profiles[i];
            _profileSelector.AddItem(record.Profile.DisplayName, i);
            _profileSelector.SetItemMetadata(i, record.ResourcePath);

            if ((preferredPath is not null && record.ResourcePath == preferredPath) || (preferredPath is null && i == 0))
            {
                selectedIndex = i;
            }
        }

        if (_profiles.Count > 0)
        {
            _profileSelector.Select(selectedIndex >= 0 ? selectedIndex : 0);
        }

        _suppressUiEvents = false;
    }

    private void RebuildPresetSelector()
    {
        _suppressUiEvents = true;
        _presetSelector.Clear();
        var supportedPresets = GetEligiblePresets();
        foreach (var preset in supportedPresets)
        {
            var display = BuildPresetDisplayLabel(preset);
            if (!preset.Runnable)
            {
                display += " (not runnable)";
            }

            _presetSelector.AddItem(display);
            _presetSelector.SetItemMetadata(_presetSelector.ItemCount - 1, preset.Name);
        }
        _suppressUiEvents = false;
    }

    private void OnProfileSelected(long index)
    {
        if (_suppressUiEvents)
        {
            return;
        }

        if (TryGetSelectedProfileRecord(out var record))
        {
            SetStoredActiveProfilePath(record.ResourcePath);
        }

        LoadSelectedProfileIntoForm();
        UpdateActionAvailability();
    }

    private void LoadSelectedProfileIntoForm()
    {
        if (!TryGetSelectedProfileRecord(out var record))
        {
            _suppressUiEvents = true;
            _displayNameEdit.Text = string.Empty;
            _outputDirectoryEdit.Text = string.Empty;
            _fileNameEdit.Text = string.Empty;
            _suppressUiEvents = false;
            UpdatePresetHintLabel();
            return;
        }

        _suppressUiEvents = true;
        _displayNameEdit.Text = record.Profile.DisplayName;
        _outputDirectoryEdit.Text = record.Profile.OutputDirectory;
        _fileNameEdit.Text = record.Profile.ExecutableFileName;
        _prebuildCheckBox.ButtonPressed = record.Profile.PrebuildDotnetSolution;
        _verboseCheckBox.ButtonPressed = record.Profile.VerboseGodotLog;
        _openFolderOnSuccessCheckBox.ButtonPressed = record.Profile.OpenOutputFolderOnSuccess;

        SelectPreset(record.Profile.ExportPresetName);
        SelectBuildMode(record.Profile.BuildMode);

        _profileStatusLabel.Text = $"Editing {record.ResourcePath}";
        _suppressUiEvents = false;
        UpdatePresetHintLabel();
    }

    private void SelectPreset(string presetName)
    {
        for (var i = 0; i < _presetSelector.ItemCount; i += 1)
        {
            if (_presetSelector.GetItemMetadata(i).AsString() == presetName)
            {
                _presetSelector.Select(i);
                return;
            }
        }

        if (!string.IsNullOrWhiteSpace(presetName))
        {
            _presetSelector.AddItem($"{presetName} [missing from active target project]");
            _presetSelector.SetItemMetadata(_presetSelector.ItemCount - 1, presetName);
            _presetSelector.Select(_presetSelector.ItemCount - 1);
            return;
        }

        if (_presetSelector.ItemCount > 0)
        {
            _presetSelector.Select(0);
        }
    }

    private void SelectBuildMode(BuildProfileBuildMode mode)
    {
        for (var i = 0; i < _buildModeSelector.ItemCount; i += 1)
        {
            if (_buildModeSelector.GetItemId(i) == (int)mode)
            {
                _buildModeSelector.Select(i);
                return;
            }
        }

        _buildModeSelector.Select(0);
    }

    private void SaveEditedTextFields()
    {
        if (_suppressUiEvents || !TryGetSelectedProfileRecord(out var record) || _profileStore is null)
        {
            return;
        }

        record.Profile.DisplayName = string.IsNullOrWhiteSpace(_displayNameEdit.Text) ? "Unnamed Build Profile" : _displayNameEdit.Text.Trim();
        record.Profile.OutputDirectory = _outputDirectoryEdit.Text.Trim();
        record.Profile.ExecutableFileName = _fileNameEdit.Text.Trim();

        _profileStore.SaveProfile(record.Profile, record.ResourcePath);
        SetStoredActiveProfilePath(record.ResourcePath);
        _profileStatusLabel.Text = $"Saved {record.ResourcePath}";
        RefreshData();
        SelectProfileByPath(record.ResourcePath);
    }

    private void SaveChoiceFields()
    {
        if (_suppressUiEvents || !TryGetSelectedProfileRecord(out var record) || _profileStore is null)
        {
            return;
        }

        var selectedPresetName = _presetSelector.ItemCount > 0
            ? _presetSelector.GetItemMetadata(_presetSelector.Selected).AsString()
            : record.Profile.ExportPresetName;

        record.Profile.ExportPresetName = selectedPresetName;
        record.Profile.BuildMode = (BuildProfileBuildMode)_buildModeSelector.GetItemId(_buildModeSelector.Selected);
        record.Profile.PrebuildDotnetSolution = _prebuildCheckBox.ButtonPressed;
        record.Profile.VerboseGodotLog = _verboseCheckBox.ButtonPressed;
        record.Profile.OpenOutputFolderOnSuccess = _openFolderOnSuccessCheckBox.ButtonPressed;

        _profileStore.SaveProfile(record.Profile, record.ResourcePath);
        SetStoredActiveProfilePath(record.ResourcePath);
        _profileStatusLabel.Text = $"Saved {record.ResourcePath}";
    }

    private void CreateProfile()
    {
        if (_profileStore is null)
        {
            return;
        }

        var preset = GetPreferredNewProfilePreset();
        var defaultProfileName = BuildProfileNameForPreset(preset, isFirstProfile: false);
        var created = _profileStore.CreateProfile(defaultProfileName, preset);
        RefreshData();
        SelectProfileByPath(created.ResourcePath);
    }

    private void DuplicateProfile()
    {
        if (!TryGetSelectedProfileRecord(out var record) || _profileStore is null)
        {
            return;
        }

        var duplicate = _profileStore.DuplicateProfile(record);
        RefreshData();
        SelectProfileByPath(duplicate.ResourcePath);
    }

    private void ConfirmDeleteProfile()
    {
        if (!TryGetSelectedProfileRecord(out _))
        {
            return;
        }

        _deleteDialog.PopupCentered(new Vector2I(520, 120));
    }

    private void DeleteSelectedProfile()
    {
        if (!TryGetSelectedProfileRecord(out var record) || _profileStore is null)
        {
            return;
        }

        _profileStore.DeleteProfile(record.ResourcePath);
        RefreshData();
    }

    private void OpenProfilesFolder()
    {
        if (_profileStore is null)
        {
            return;
        }

        OS.ShellOpen(_profileStore.ProfilesAbsolutePath);
    }

    private void OpenConfiguredOutputFolder()
    {
        if (!TryGetSelectedProfileRecord(out var record))
        {
            return;
        }

        try
        {
            if (!TryResolveConfiguredBuildTargetProjectRoot(out var targetProjectRoot, out var errorMessage))
            {
                throw new InvalidOperationException(errorMessage);
            }

            var outputDirectory = PathHelpers.ResolveDirectory(record.Profile.OutputDirectory, targetProjectRoot);
            Directory.CreateDirectory(outputDirectory);
            OS.ShellOpen(outputDirectory);
        }
        catch (Exception ex)
        {
            OS.Alert(ex.Message, "Sea Shell DevTools");
        }
    }

    private void StartBuild()
    {
        if (!TryResolveBuildRequest(out var record, out var preset, out var buildEditorPath, out var targetProjectRoot, out var errorMessage))
        {
            OS.Alert(errorMessage, "Sea Shell DevTools");
            return;
        }

        if (!_runner.StartBuild(record.Profile.ToSnapshot(record.ResourcePath), preset, buildEditorPath, targetProjectRoot))
        {
            OS.Alert("A build is already running. Abort it before starting another one.", "Sea Shell DevTools");
            return;
        }

        _visibleRunId = -1;
        MakeVisible();
        UpdateActionAvailability();
    }

    private void AbortBuild()
    {
        _runner.Abort();
        UpdateActionAvailability();
    }

    private void DrainRunnerLogs()
    {
        while (_runner.TryDequeueLog(out var entry) && entry is not null)
        {
            var snapshot = _runner.GetSnapshot();
            if (_visibleRunId != snapshot.RunId)
            {
                _logView.Clear();
                _visibleRunId = snapshot.RunId;
            }

            AppendLogEntry(entry);
        }
    }

    private void AppendLogEntry(BuildLogEntry entry)
    {
        var timestamp = entry.TimestampUtc.ToLocalTime().ToString("HH:mm:ss");
        var color = entry.Severity switch
        {
            BuildLogSeverity.Success => "#7ad7a8",
            BuildLogSeverity.Warning => "#ffcf70",
            BuildLogSeverity.Error => "#ff8a8a",
            _ => "#b6c8dc",
        };

        var severity = entry.Severity.ToString().ToUpperInvariant();
        var message = EscapeBbCode(entry.Message);
        var step = EscapeBbCode(entry.Step);
        _logView.AppendText($"[color=#7f94ac]{timestamp}[/color] [color={color}][b]{severity}[/b][/color] [b]{step}[/b] {message}\n");
    }

    private void AppendStandaloneLog(BuildLogSeverity severity, string step, string message)
    {
        AppendLogEntry(new BuildLogEntry(DateTime.UtcNow, step, severity, message));
    }

    private void RefreshRunStatus()
    {
        var snapshot = _runner.GetSnapshot();
        _progressBar.Value = Math.Round(snapshot.Progress01 * 100.0f, 1);
        _progressLabel.Text = $"{Math.Round(snapshot.Progress01 * 100.0f)}% estimate";
        _stepLabel.Text = $"Step: {snapshot.CurrentStep}";
        _detailLabel.Text = snapshot.Detail;
        _elapsedLabel.Text = $"Elapsed: {snapshot.Elapsed:hh\\:mm\\:ss}";

        if (_visibleRunId != snapshot.RunId && snapshot.RunId > 0 && snapshot.IsBusy)
        {
            _logView.Clear();
            _visibleRunId = snapshot.RunId;
        }

        if (snapshot.State == BuildRunState.Succeeded && snapshot.RunId != _lastAutoOpenedRunId && snapshot.OpenOutputFolderOnSuccess && snapshot.OutputDirectoryAbsolute is not null)
        {
            _lastAutoOpenedRunId = snapshot.RunId;
            OS.ShellOpen(snapshot.OutputDirectoryAbsolute);
        }

        UpdateActionAvailability();
    }

    private void UpdateActionAvailability()
    {
        if (_buildButton is null ||
            _abortButton is null ||
            _copyLinkCommandButton is null ||
            _runLinkCommandButton is null ||
            _linkTargetPathEdit is null ||
            _buildEditorPathEdit is null ||
            _browseLinkTargetButton is null ||
            _browseBuildEditorButton is null ||
            _rememberLinkTargetButton is null ||
            _linkEnablePluginCheckBox is null ||
            _linkBuildSolutionsCheckBox is null)
        {
            return;
        }

        var snapshot = _runner.GetSnapshot();
        var hasProfile = TryGetSelectedProfileRecord(out _);
        var interactionsBlocked = snapshot.IsBusy || _isLinkCommandRunning;
        var buildTargetResolved = TryResolveConfiguredBuildTargetProjectRoot(out _, out _);
        var buildEditorResolved = TryResolveBuildEditorExecutablePath(out _, out _);
        var selectedPresetAvailable = TryResolveSelectedPresetForBuild(out _, out _);

        _duplicateProfileButton.Disabled = !hasProfile || interactionsBlocked;
        _deleteProfileButton.Disabled = !hasProfile || interactionsBlocked;
        _buildButton.Disabled = !hasProfile || interactionsBlocked || !buildTargetResolved || !buildEditorResolved || !selectedPresetAvailable;
        _abortButton.Visible = snapshot.IsBusy;
        _abortButton.Disabled = !snapshot.IsBusy;
        _openOutputFolderButton.Disabled = !hasProfile || !buildTargetResolved;

        var formEnabled = hasProfile && !interactionsBlocked;
        _displayNameEdit.Editable = formEnabled;
        _outputDirectoryEdit.Editable = formEnabled;
        _fileNameEdit.Editable = formEnabled;
        _presetSelector.Disabled = !formEnabled;
        _buildModeSelector.Disabled = !formEnabled;
        _prebuildCheckBox.Disabled = !formEnabled;
        _verboseCheckBox.Disabled = !formEnabled;
        _openFolderOnSuccessCheckBox.Disabled = !formEnabled;

        var linkTargetResolved = TryResolveExplicitTargetProjectRoot(_linkTargetPathEdit.Text, out _, out _);
        _linkTargetPathEdit.Editable = !interactionsBlocked;
        _buildEditorPathEdit.Editable = !interactionsBlocked;
        _browseLinkTargetButton.Disabled = interactionsBlocked;
        _browseBuildEditorButton.Disabled = interactionsBlocked;
        _rememberLinkTargetButton.Disabled = interactionsBlocked || !linkTargetResolved;
        _linkEnablePluginCheckBox.Disabled = interactionsBlocked;
        _linkBuildSolutionsCheckBox.Disabled = interactionsBlocked;
        _copyLinkCommandButton.Disabled = !linkTargetResolved;
        _runLinkCommandButton.Disabled = interactionsBlocked || !linkTargetResolved;
    }

    private ExportPresetInfo? GetPreferredDefaultPreset()
    {
        var presets = GetEligiblePresets();
        return presets.FirstOrDefault(static preset => preset.Platform.Equals("Windows Desktop", StringComparison.OrdinalIgnoreCase)) ??
            presets.FirstOrDefault();
    }

    private ExportPresetInfo? GetPreferredNewProfilePreset()
    {
        if (TryGetSelectedProfileRecord(out var record))
        {
            return _presetCatalog?.FindByName(record.Profile.ExportPresetName) ?? GetPreferredDefaultPreset();
        }

        return GetPreferredDefaultPreset();
    }

    private IReadOnlyList<ExportPresetInfo> GetEligiblePresets()
    {
        return (_presetCatalog?.Presets ?? Array.Empty<ExportPresetInfo>())
            .Where(SupportedBuildPlatforms.IsEligiblePreset)
            .ToArray();
    }

    private string BuildPresetDisplayLabel(ExportPresetInfo preset)
    {
        if (preset.Platform.Equals("Android", StringComparison.OrdinalIgnoreCase))
        {
            var extension = Path.GetExtension(preset.ExportPath ?? string.Empty);
            if (extension.Equals(".aab", StringComparison.OrdinalIgnoreCase))
            {
                return $"{preset.Name} [Android AAB unsupported here]";
            }

            return $"{preset.Name} [Android APK]";
        }

        if (preset.Platform.Equals("Web", StringComparison.OrdinalIgnoreCase))
        {
            return $"{preset.Name} [Web HTML]";
        }

        return $"{preset.Name} [Windows EXE]";
    }

    private static string BuildPresetSummaryLabel(ExportPresetInfo preset)
    {
        if (preset.Platform.Equals("Web", StringComparison.OrdinalIgnoreCase))
        {
            return $"{preset.Name} (Web)";
        }

        return preset.Platform.Equals("Android", StringComparison.OrdinalIgnoreCase)
            ? $"{preset.Name} (Android)"
            : $"{preset.Name} (Windows)";
    }

    private void OnPresetSelected(long _index)
    {
        if (_suppressUiEvents)
        {
            return;
        }

        AdjustOutputFileNameForSelectedPreset();
        SaveChoiceFields();
    }

    private void AdjustOutputFileNameForSelectedPreset()
    {
        if (_presetSelector.ItemCount == 0)
        {
            return;
        }

        var presetName = _presetSelector.GetItemMetadata(_presetSelector.Selected).AsString();
        var preset = _presetCatalog?.FindByName(presetName);
        if (!SupportedBuildPlatforms.TryResolveFromPreset(preset, out var platformInfo, out _))
        {
            return;
        }

        var currentFileName = _fileNameEdit.Text.Trim();
        if (string.IsNullOrWhiteSpace(currentFileName))
        {
            _fileNameEdit.Text = SupportedBuildPlatforms.BuildDefaultOutputFileName("BuildOutput", platformInfo);
            return;
        }

        var currentExtension = Path.GetExtension(currentFileName);
        if (string.IsNullOrWhiteSpace(currentExtension))
        {
            _fileNameEdit.Text = SupportedBuildPlatforms.BuildDefaultOutputFileName(currentFileName, platformInfo);
            return;
        }

        var isKnownSupportedExtension = SupportedBuildPlatforms.All.Any(info =>
            info.OutputFileExtension.Equals(currentExtension, StringComparison.OrdinalIgnoreCase));

        if (isKnownSupportedExtension && !currentExtension.Equals(platformInfo.OutputFileExtension, StringComparison.OrdinalIgnoreCase))
        {
            _fileNameEdit.Text = SupportedBuildPlatforms.BuildDefaultOutputFileName(Path.GetFileNameWithoutExtension(currentFileName), platformInfo);
        }
    }

    private bool TryGetSelectedProfileRecord(out BuildProfileRecord record)
    {
        record = null!;
        if (_profileSelector.ItemCount == 0 || _profileSelector.Selected < 0)
        {
            return false;
        }

        var resourcePath = _profileSelector.GetItemMetadata(_profileSelector.Selected).AsString();
        var selectedRecord = _profiles.FirstOrDefault(profile => profile.ResourcePath == resourcePath);
        if (selectedRecord is null)
        {
            return false;
        }

        record = selectedRecord;
        return true;
    }

    private void SelectProfileByPath(string resourcePath)
    {
        for (var i = 0; i < _profileSelector.ItemCount; i += 1)
        {
            if (_profileSelector.GetItemMetadata(i).AsString() != resourcePath)
            {
                continue;
            }

            _profileSelector.Select(i);
            SetStoredActiveProfilePath(resourcePath);
            LoadSelectedProfileIntoForm();
            UpdateActionAvailability();
            return;
        }
    }

    private string? GetStoredActiveProfilePath()
    {
        var settings = EditorInterface.Singleton.GetEditorSettings();
        return settings.HasSetting(ActiveProfileSettingKey)
            ? settings.GetSetting(ActiveProfileSettingKey).AsString()
            : null;
    }

    private void SetStoredActiveProfilePath(string resourcePath)
    {
        var settings = EditorInterface.Singleton.GetEditorSettings();
        settings.SetSetting(ActiveProfileSettingKey, resourcePath);
    }

    private void LoadStoredTargetProjectPath()
    {
        var settings = EditorInterface.Singleton.GetEditorSettings();
        var storedPath = settings.HasSetting(TargetProjectPathSettingKey)
            ? settings.GetSetting(TargetProjectPathSettingKey).AsString()
            : settings.HasSetting(LegacyLinkTargetProjectSettingKey)
                ? settings.GetSetting(LegacyLinkTargetProjectSettingKey).AsString()
                : string.Empty;

        if (!settings.HasSetting(TargetProjectPathSettingKey) && !string.IsNullOrWhiteSpace(storedPath))
        {
            settings.SetSetting(TargetProjectPathSettingKey, storedPath);
        }

        _suppressUiEvents = true;
        _linkTargetPathEdit.Text = storedPath;
        _suppressUiEvents = false;
    }

    private void LoadStoredBuildEditorPath()
    {
        var settings = EditorInterface.Singleton.GetEditorSettings();
        var storedPath = settings.HasSetting(BuildEditorExecutablePathSettingKey)
            ? settings.GetSetting(BuildEditorExecutablePathSettingKey).AsString()
            : string.Empty;

        _suppressUiEvents = true;
        _buildEditorPathEdit.Text = storedPath;
        _suppressUiEvents = false;
    }

    private void StoreTargetProjectPath(string path)
    {
        var settings = EditorInterface.Singleton.GetEditorSettings();
        settings.SetSetting(TargetProjectPathSettingKey, path);
    }

    private void StoreBuildEditorPath(string path)
    {
        var settings = EditorInterface.Singleton.GetEditorSettings();
        settings.SetSetting(BuildEditorExecutablePathSettingKey, path);
    }

    private void OnLinkTargetPathChanged()
    {
        if (_suppressUiEvents)
        {
            return;
        }

        StoreTargetProjectPath(_linkTargetPathEdit.Text.Trim());
        _presetCatalog = LoadConfiguredTargetPresetCatalog();
        RebuildPresetSelector();
        LoadSelectedProfileIntoForm();
        UpdateLinkCommandPreview();
        UpdateActionAvailability();
    }

    private void OnBuildEditorPathChanged()
    {
        if (_suppressUiEvents)
        {
            return;
        }

        StoreBuildEditorPath(_buildEditorPathEdit.Text.Trim());
        UpdateBuildEditorStatus();
        UpdateActionAvailability();
    }

    private void BrowseForLinkTarget()
    {
        var startDir = ResolveInitialBrowseDirectory();
        if (!string.IsNullOrWhiteSpace(startDir) && Directory.Exists(startDir))
        {
            _linkProjectDialog.CurrentDir = startDir.Replace('\\', '/');
        }

        _linkProjectDialog.PopupCentered();
    }

    private void BrowseForBuildEditor()
    {
        var startDir = ResolveInitialBuildEditorBrowseDirectory();
        if (!string.IsNullOrWhiteSpace(startDir) && Directory.Exists(startDir))
        {
            _buildEditorDialog.CurrentDir = startDir.Replace('\\', '/');
        }

        _buildEditorDialog.PopupCentered();
    }

    private string ResolveInitialBrowseDirectory()
    {
        if (TryResolveExplicitTargetProjectRoot(_linkTargetPathEdit.Text, out var resolvedRoot, out _))
        {
            return resolvedRoot;
        }

        var currentText = _linkTargetPathEdit.Text.Trim().Trim('"');
        if (Directory.Exists(currentText))
        {
            return Path.GetFullPath(currentText);
        }

        return Path.GetDirectoryName(ProjectSettings.GlobalizePath("res://")) ?? ProjectSettings.GlobalizePath("res://");
    }

    private string ResolveInitialBuildEditorBrowseDirectory()
    {
        var currentText = _buildEditorPathEdit.Text.Trim().Trim('"');
        if (File.Exists(currentText))
        {
            return Path.GetDirectoryName(Path.GetFullPath(currentText)) ?? currentText;
        }

        if (Directory.Exists(currentText))
        {
            return Path.GetFullPath(currentText);
        }

        return Path.GetDirectoryName(OS.GetExecutablePath()) ?? System.Environment.CurrentDirectory;
    }

    private void OnLinkProjectDirectorySelected(string dir)
    {
        _suppressUiEvents = true;
        _linkTargetPathEdit.Text = dir.Replace('/', Path.DirectorySeparatorChar);
        _suppressUiEvents = false;
        StoreTargetProjectPath(_linkTargetPathEdit.Text);
        _presetCatalog = LoadConfiguredTargetPresetCatalog();
        RebuildPresetSelector();
        LoadSelectedProfileIntoForm();
        UpdateLinkCommandPreview();
        UpdateActionAvailability();
    }

    private void OnBuildEditorFileSelected(string path)
    {
        _suppressUiEvents = true;
        _buildEditorPathEdit.Text = path.Replace('/', Path.DirectorySeparatorChar);
        _suppressUiEvents = false;
        StoreBuildEditorPath(_buildEditorPathEdit.Text);
        UpdateBuildEditorStatus();
        UpdateActionAvailability();
    }

    private void UpdateLinkCommandPreview()
    {
        if (_linkTargetPathEdit is null || _linkTargetStatusLabel is null || _linkCommandPreview is null)
        {
            return;
        }

        var rawTargetInput = _linkTargetPathEdit.Text.Trim();
        if (string.IsNullOrWhiteSpace(rawTargetInput))
        {
            var hostProjectRoot = ProjectSettings.GlobalizePath("res://");
            _linkTargetStatusLabel.Text = $"Build target: current host project ({hostProjectRoot}). Leave this blank for local Windows/Android builds, or choose another Godot project to export externally or link the addon into.";
            _linkCommandPreview.Text = "Choose or paste another Godot project path to generate the local addon link command.";
            UpdateActionAvailability();
            return;
        }

        if (!TryResolveExplicitTargetProjectRoot(rawTargetInput, out var projectRoot, out var statusMessage))
        {
            _linkTargetStatusLabel.Text = statusMessage;
            _linkCommandPreview.Text = "Choose or paste a Godot project path to generate the local addon link command.";
            UpdateActionAvailability();
            return;
        }

        var projectInfo = GodotProjectInfo.Load(projectRoot);
        var runtimeMessage = projectInfo.LooksLikeCSharpProject
            ? "C# markers detected."
            : "No C# markers detected. This is a good fit for external GDScript Web builds.";

        _linkTargetStatusLabel.Text = $"Resolved target project root: {projectRoot} {runtimeMessage} Build preset discovery and output paths now use this target project.";
        _linkCommandPreview.Text = BuildLinkCommandPreview(projectRoot);
        UpdateActionAvailability();
    }

    private void UpdateBuildEditorStatus()
    {
        if (_buildEditorStatusLabel is null || _buildEditorPathEdit is null)
        {
            return;
        }

        if (TryResolveBuildEditorExecutablePath(out var buildEditorPath, out var statusMessage))
        {
            if (string.IsNullOrWhiteSpace(_buildEditorPathEdit.Text.Trim()))
            {
                _buildEditorStatusLabel.Text = $"Using the current Godot editor for builds: {buildEditorPath}. Set an override when an external target needs a different editor/template install, such as a standard editor with Web templates.";
            }
            else
            {
                _buildEditorStatusLabel.Text = $"Using build editor override: {buildEditorPath}";
            }

            return;
        }

        _buildEditorStatusLabel.Text = statusMessage;
    }

    private ExportPresetCatalog LoadConfiguredTargetPresetCatalog()
    {
        if (TryResolveConfiguredBuildTargetProjectRoot(out var projectRoot, out _))
        {
            return ExportPresetCatalog.Load(projectRoot);
        }

        return ExportPresetCatalog.CreateEmpty(Path.Combine(ProjectSettings.GlobalizePath("res://"), "export_presets.cfg"));
    }

    private void UpdatePresetHintLabel()
    {
        if (_presetHintLabel is null)
        {
            return;
        }

        var targetDescription = TryResolveConfiguredBuildTargetProjectRoot(out var projectRoot, out var targetMessage)
            ? projectRoot.Equals(ProjectSettings.GlobalizePath("res://"), StringComparison.OrdinalIgnoreCase)
                ? "the current host project"
                : $"target project '{projectRoot}'"
            : null;

        var supportedPresets = GetEligiblePresets();
        var presetNames = supportedPresets.Select(BuildPresetSummaryLabel).ToArray();

        if (targetDescription is null)
        {
            _presetHintLabel.Text = $"Build presets cannot be loaded until the target project path resolves cleanly. {targetMessage}";
            return;
        }

        if (!TryGetSelectedProfileRecord(out var record))
        {
            _presetHintLabel.Text = $"Build presets come from {targetDescription}'s export_presets.cfg.";
            return;
        }

        var selectedPresetMissing = _presetCatalog?.FindByName(record.Profile.ExportPresetName) is null && !string.IsNullOrWhiteSpace(record.Profile.ExportPresetName);
        if (selectedPresetMissing)
        {
            var detectedPresets = presetNames.Length == 0
                ? "No supported presets were detected."
                : $"Detected supported presets: {string.Join(", ", presetNames)}.";
            _presetHintLabel.Text = $"Profile '{record.Profile.DisplayName}' expects preset '{record.Profile.ExportPresetName}', but it was not found in {targetDescription}. {detectedPresets}";
            return;
        }

        if (presetNames.Length == 0)
        {
            _presetHintLabel.Text = $"No supported Windows Desktop, Android, or Web presets were detected in {targetDescription}. Create one in Project > Export, then press Refresh.";
            return;
        }

        _presetHintLabel.Text = $"Detected supported presets in {targetDescription}: {string.Join(", ", presetNames)}. Android support remains APK-first, and external Web builds may need a standard Godot editor with matching Web templates.";
    }

    private bool TryResolveConfiguredBuildTargetProjectRoot(out string projectRoot, out string message)
    {
        var rawTargetInput = _linkTargetPathEdit?.Text.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(rawTargetInput))
        {
            projectRoot = ProjectSettings.GlobalizePath("res://");
            message = $"Using the current host project at '{projectRoot}'.";
            return true;
        }

        return TryResolveExplicitTargetProjectRoot(rawTargetInput, out projectRoot, out message);
    }

    private bool TryResolveBuildEditorExecutablePath(out string buildEditorPath, out string message)
    {
        buildEditorPath = string.Empty;
        message = "Choose a valid Godot editor executable path, or leave Build Editor Override blank to use the current editor.";

        var rawValue = _buildEditorPathEdit?.Text.Trim().Trim('"') ?? string.Empty;
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            buildEditorPath = OS.GetExecutablePath();
            if (File.Exists(buildEditorPath))
            {
                message = $"Using current Godot editor executable '{buildEditorPath}'.";
                return true;
            }

            message = $"The current Godot editor executable could not be found at '{buildEditorPath}'.";
            return false;
        }

        try
        {
            buildEditorPath = Path.GetFullPath(rawValue);
        }
        catch (Exception ex)
        {
            message = ex.Message;
            return false;
        }

        if (!File.Exists(buildEditorPath))
        {
            message = $"Build editor override was set to '{buildEditorPath}', but that file does not exist.";
            return false;
        }

        message = $"Using build editor override '{buildEditorPath}'.";
        return true;
    }

    private bool TryResolveSelectedPresetForBuild(out ExportPresetInfo? preset, out string message)
    {
        preset = null;
        message = "Select or create a build profile first.";

        if (!TryGetSelectedProfileRecord(out var record))
        {
            return false;
        }

        preset = _presetCatalog?.FindByName(record.Profile.ExportPresetName);
        if (preset is null)
        {
            message = $"Build profile '{record.Profile.DisplayName}' expects export preset '{record.Profile.ExportPresetName}', but that preset was not found in the active target project.";
            return false;
        }

        message = $"Using export preset '{preset.Name}'.";
        return true;
    }

    private bool TryResolveBuildRequest(out BuildProfileRecord record, out ExportPresetInfo? preset, out string buildEditorPath, out string targetProjectRoot, out string errorMessage)
    {
        record = null!;
        preset = null;
        buildEditorPath = string.Empty;
        targetProjectRoot = string.Empty;
        errorMessage = "Select or create a build profile first.";

        if (!TryGetSelectedProfileRecord(out record))
        {
            return false;
        }

        if (!TryResolveConfiguredBuildTargetProjectRoot(out targetProjectRoot, out errorMessage))
        {
            return false;
        }

        if (!TryResolveBuildEditorExecutablePath(out buildEditorPath, out errorMessage))
        {
            return false;
        }

        if (!TryResolveSelectedPresetForBuild(out preset, out errorMessage))
        {
            return false;
        }

        errorMessage = string.Empty;
        return true;
    }

    private static string BuildProfileNameForPreset(ExportPresetInfo? preset, bool isFirstProfile)
    {
        if (preset?.Platform.Equals("Web", StringComparison.OrdinalIgnoreCase) == true)
        {
            return isFirstProfile ? "Default Web Build" : "New Web Build";
        }

        if (preset?.Platform.Equals("Android", StringComparison.OrdinalIgnoreCase) == true)
        {
            return isFirstProfile ? "Default Android APK Build" : "New Android APK Build";
        }

        return isFirstProfile ? "Default Windows Build" : "New Build Profile";
    }

    private string BuildLinkCommandPreview(string projectRoot)
    {
        var scriptPath = ProjectSettings.GlobalizePath("res://tools/link-addon.ps1");
        var command = new StringBuilder();
        command.Append("powershell -NoProfile -ExecutionPolicy Bypass -File ");
        command.Append(QuotePowerShellArgument(scriptPath));
        command.Append(" -ProjectPaths ");
        command.Append(QuotePowerShellArgument(projectRoot));

        if (_linkEnablePluginCheckBox.ButtonPressed)
        {
            command.Append(" -EnablePlugin");
        }

        if (_linkBuildSolutionsCheckBox.ButtonPressed)
        {
            command.Append(" -BuildSolutions -GodotExe ");
            command.Append(QuotePowerShellArgument(OS.GetExecutablePath()));
        }

        return command.ToString();
    }

    private void CopyLinkCommand()
    {
        if (!TryResolveExplicitTargetProjectRoot(_linkTargetPathEdit.Text, out var projectRoot, out var errorMessage))
        {
            OS.Alert(errorMessage, "Sea Shell DevTools");
            return;
        }

        var command = BuildLinkCommandPreview(projectRoot);
        DisplayServer.ClipboardSet(command);
        AppendStandaloneLog(BuildLogSeverity.Info, "LinkAddon", $"Copied link command for '{projectRoot}' to the clipboard.");
    }

    private async void RunLinkCommandNow()
    {
        if (_isLinkCommandRunning)
        {
            return;
        }

        if (!TryResolveExplicitTargetProjectRoot(_linkTargetPathEdit.Text, out var projectRoot, out var errorMessage))
        {
            OS.Alert(errorMessage, "Sea Shell DevTools");
            return;
        }

        var scriptPath = ProjectSettings.GlobalizePath("res://tools/link-addon.ps1");
        if (!File.Exists(scriptPath))
        {
            OS.Alert($"The link helper script was not found at '{scriptPath}'.", "Sea Shell DevTools");
            return;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(scriptPath);
        startInfo.ArgumentList.Add("-ProjectPaths");
        startInfo.ArgumentList.Add(projectRoot);

        if (_linkEnablePluginCheckBox.ButtonPressed)
        {
            startInfo.ArgumentList.Add("-EnablePlugin");
        }

        if (_linkBuildSolutionsCheckBox.ButtonPressed)
        {
            startInfo.ArgumentList.Add("-BuildSolutions");
            startInfo.ArgumentList.Add("-GodotExe");
            startInfo.ArgumentList.Add(OS.GetExecutablePath());
        }

        _isLinkCommandRunning = true;
        UpdateActionAvailability();
        AppendStandaloneLog(BuildLogSeverity.Info, "LinkAddon", $"Running local addon link command for '{projectRoot}'.");

        try
        {
            using var process = new Process { StartInfo = startInfo };
            if (!process.Start())
            {
                throw new InvalidOperationException("Could not start the local addon link command.");
            }

            var stdoutTask = process.StandardOutput.ReadToEndAsync();
            var stderrTask = process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();

            var stdout = await stdoutTask;
            var stderr = await stderrTask;

            AppendProcessOutput("LinkAddon", stdout, BuildLogSeverity.Info);
            AppendProcessOutput("LinkAddon", stderr, BuildLogSeverity.Warning);

            if (process.ExitCode != 0)
            {
                AppendStandaloneLog(BuildLogSeverity.Error, "LinkAddon", $"Link command failed for '{projectRoot}' with exit code {process.ExitCode}.");
                OS.Alert($"Link command failed for '{projectRoot}'. Check the run log for details.", "Sea Shell DevTools");
                return;
            }

            AppendStandaloneLog(BuildLogSeverity.Success, "LinkAddon", $"Linked Sea Shell DevTools into '{projectRoot}'.");
            OS.Alert($"Linked Sea Shell DevTools into:{System.Environment.NewLine}{projectRoot}", "Sea Shell DevTools");
        }
        catch (Exception ex)
        {
            AppendStandaloneLog(BuildLogSeverity.Error, "LinkAddon", ex.Message);
            OS.Alert(ex.Message, "Sea Shell DevTools");
        }
        finally
        {
            _isLinkCommandRunning = false;
            UpdateActionAvailability();
        }
    }

    private void RememberLinkTargetProject()
    {
        if (!TryResolveExplicitTargetProjectRoot(_linkTargetPathEdit.Text, out var projectRoot, out var errorMessage))
        {
            OS.Alert(errorMessage, "Sea Shell DevTools");
            return;
        }

        try
        {
            var toolsDirectory = ProjectSettings.GlobalizePath("res://tools");
            Directory.CreateDirectory(toolsDirectory);

            var manifestPath = Path.Combine(toolsDirectory, "linked-projects.local.json");
            LinkedProjectsManifest manifest;

            if (File.Exists(manifestPath))
            {
                var raw = File.ReadAllText(manifestPath);
                manifest = JsonSerializer.Deserialize<LinkedProjectsManifest>(raw) ?? new LinkedProjectsManifest();
            }
            else
            {
                manifest = new LinkedProjectsManifest();
            }

            if (!manifest.Projects.Any(path => string.Equals(Path.GetFullPath(path), projectRoot, StringComparison.OrdinalIgnoreCase)))
            {
                manifest.Projects.Add(projectRoot);
            }

            var json = JsonSerializer.Serialize(manifest, new JsonSerializerOptions
            {
                WriteIndented = true,
            });

            File.WriteAllText(manifestPath, json + System.Environment.NewLine, new UTF8Encoding(false));
            AppendStandaloneLog(BuildLogSeverity.Success, "LinkAddon", $"Remembered '{projectRoot}' in tools/linked-projects.local.json.");
            OS.Alert($"Saved target project in:{System.Environment.NewLine}{manifestPath}", "Sea Shell DevTools");
        }
        catch (Exception ex)
        {
            AppendStandaloneLog(BuildLogSeverity.Error, "LinkAddon", ex.Message);
            OS.Alert(ex.Message, "Sea Shell DevTools");
        }
    }

    private void OpenToolsFolder()
    {
        OS.ShellOpen(ProjectSettings.GlobalizePath("res://tools"));
    }

    private void AppendProcessOutput(string step, string rawOutput, BuildLogSeverity defaultSeverity)
    {
        foreach (var rawLine in rawOutput.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var severity = line.Contains("warning", StringComparison.OrdinalIgnoreCase)
                ? BuildLogSeverity.Warning
                : line.Contains("error", StringComparison.OrdinalIgnoreCase)
                    ? BuildLogSeverity.Error
                    : defaultSeverity;

            AppendStandaloneLog(severity, step, line);
        }
    }

    private bool TryResolveExplicitTargetProjectRoot(string rawInput, out string projectRoot, out string message)
    {
        projectRoot = string.Empty;
        message = "Choose a Godot project folder or paste any file path inside a Godot project.";

        var input = rawInput.Trim().Trim('"');
        if (string.IsNullOrWhiteSpace(input))
        {
            return false;
        }

        string? candidatePath = null;
        if (Directory.Exists(input))
        {
            candidatePath = Path.GetFullPath(input);
        }
        else if (File.Exists(input))
        {
            candidatePath = Path.GetDirectoryName(Path.GetFullPath(input));
        }
        else
        {
            try
            {
                candidatePath = Path.GetFullPath(input);
            }
            catch (Exception ex)
            {
                message = ex.Message;
                return false;
            }
        }

        var directory = candidatePath;
        while (!string.IsNullOrWhiteSpace(directory))
        {
            if (File.Exists(Path.Combine(directory, "project.godot")))
            {
                projectRoot = directory;
                message = $"Resolved target project root: {projectRoot}";
                return true;
            }

            directory = Directory.GetParent(directory)?.FullName;
        }

        message = "No project.godot was found at that path or any of its parent folders.";
        return false;
    }

    private static string QuotePowerShellArgument(string value)
    {
        return $"'{value.Replace("'", "''")}'";
    }

    private static string EscapeBbCode(string text)
    {
        var builder = new StringBuilder(text.Length);
        foreach (var ch in text)
        {
            builder.Append(ch switch
            {
                '[' => "[lb]",
                ']' => "[rb]",
                _ => ch,
            });
        }

        return builder.ToString();
    }

    private sealed class LinkedProjectsManifest
    {
        public List<string> Projects { get; set; } = [];
    }
}
