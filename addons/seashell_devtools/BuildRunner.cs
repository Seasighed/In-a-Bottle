using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;

namespace SeaShellDevTools;

public sealed class BuildStatusSnapshot
{
    public required long RunId { get; init; }

    public required BuildRunState State { get; init; }

    public required bool IsBusy { get; init; }

    public required float Progress01 { get; init; }

    public required string CurrentStep { get; init; }

    public required string Detail { get; init; }

    public required TimeSpan Elapsed { get; init; }

    public required string? OutputDirectoryAbsolute { get; init; }

    public required string? OutputFileAbsolute { get; init; }

    public required bool OpenOutputFolderOnSuccess { get; init; }
}

internal sealed class BuildRunner
{
    private const float ValidationProgress = 0.15f;
    private const float BuildProgress = 0.40f;
    private const float ExportProgress = 0.90f;

    private readonly object _sync = new();
    private readonly ConcurrentQueue<BuildLogEntry> _pendingLogs = new();

    private Process? _activeProcess;
    private Task? _runTask;
    private bool _abortRequested;
    private long _runId;
    private BuildRunState _state = BuildRunState.Idle;
    private float _progress01;
    private float _phaseFloor;
    private float _phaseCap;
    private DateTime _phaseStartedUtc = DateTime.UtcNow;
    private DateTime? _startedUtc;
    private DateTime? _finishedUtc;
    private string _currentStep = "Idle";
    private string _detail = "Ready to build.";
    private string? _outputDirectoryAbsolute;
    private string? _outputFileAbsolute;
    private bool _openOutputFolderOnSuccess;

    public bool IsBusy
    {
        get
        {
            lock (_sync)
            {
                return _runTask is { IsCompleted: false };
            }
        }
    }

    public bool StartBuild(BuildProfileSnapshot profile, ExportPresetInfo? preset, string editorExecutablePath, string projectRootAbsolute)
    {
        lock (_sync)
        {
            if (_runTask is { IsCompleted: false })
            {
                return false;
            }

            _runId += 1;
            _abortRequested = false;
            _activeProcess = null;
            _progress01 = 0.0f;
            _phaseFloor = 0.0f;
            _phaseCap = ValidationProgress;
            _phaseStartedUtc = DateTime.UtcNow;
            _startedUtc = DateTime.UtcNow;
            _finishedUtc = null;
            _state = BuildRunState.Validating;
            _currentStep = "Validating";
            _detail = $"Preparing build profile '{profile.DisplayName}'.";
            _outputDirectoryAbsolute = null;
            _outputFileAbsolute = null;
            _openOutputFolderOnSuccess = profile.OpenOutputFolderOnSuccess;
            _runTask = Task.Run(async () => await RunBuildAsync(profile, preset, editorExecutablePath, projectRootAbsolute));
        }

        Log(BuildLogSeverity.Info, "Validating", $"Starting build for profile '{profile.DisplayName}'.");
        return true;
    }

    public void Abort()
    {
        Process? processToKill = null;

        lock (_sync)
        {
            if (_runTask is not { IsCompleted: false })
            {
                return;
            }

            _abortRequested = true;
            _detail = "Abort requested. Waiting for the current child process to stop.";
            processToKill = _activeProcess;
        }

        Log(BuildLogSeverity.Warning, "Cancel", "Abort requested. Partial outputs may remain in the target folder.");

        if (processToKill is null)
        {
            return;
        }

        try
        {
            if (!processToKill.HasExited)
            {
                processToKill.Kill(entireProcessTree: true);
            }
        }
        catch
        {
            // If the process is already gone there is nothing else to do.
        }
    }

    public BuildStatusSnapshot GetSnapshot()
    {
        lock (_sync)
        {
            var elapsed = (_finishedUtc ?? DateTime.UtcNow) - (_startedUtc ?? DateTime.UtcNow);
            var progress = _progress01;

            if (IsEstimating(_state))
            {
                var phaseElapsed = (DateTime.UtcNow - _phaseStartedUtc).TotalSeconds;
                var target = _phaseFloor + MathF.Min((_phaseCap - _phaseFloor) * 0.82f, (float)(phaseElapsed * 0.015));
                progress = Math.Max(progress, target);
            }

            return new BuildStatusSnapshot
            {
                RunId = _runId,
                State = _state,
                IsBusy = _runTask is { IsCompleted: false },
                Progress01 = Math.Clamp(progress, 0.0f, 1.0f),
                CurrentStep = _currentStep,
                Detail = _detail,
                Elapsed = elapsed < TimeSpan.Zero ? TimeSpan.Zero : elapsed,
                OutputDirectoryAbsolute = _outputDirectoryAbsolute,
                OutputFileAbsolute = _outputFileAbsolute,
                OpenOutputFolderOnSuccess = _openOutputFolderOnSuccess,
            };
        }
    }

    public bool TryDequeueLog(out BuildLogEntry? entry)
    {
        return _pendingLogs.TryDequeue(out entry);
    }

    private async Task RunBuildAsync(BuildProfileSnapshot profile, ExportPresetInfo? preset, string editorExecutablePath, string projectRootAbsolute)
    {
        try
        {
            var request = Validate(profile, preset, editorExecutablePath, projectRootAbsolute);

            if (request.ShouldBuildSolution)
            {
                await RunProcessStepAsync(
                    BuildRunState.BuildingSolution,
                    "BuildingSolution",
                    "Building C# solution",
                    "Compiling the Godot C# solution before export.",
                    editorExecutablePath,
                    request.BuildSolutionArguments);
            }
            else
            {
                Log(BuildLogSeverity.Info, "BuildingSolution", request.BuildSolutionSkipMessage);
                SetProgress(BuildProgress);
            }

            await RunProcessStepAsync(
                BuildRunState.Exporting,
                "Exporting",
                $"Exporting {request.ArtifactLabel}",
                $"Running Godot export preset '{request.ExportPresetName}' to '{request.OutputFileAbsolute}'.",
                editorExecutablePath,
                request.ExportArguments);

            TransitionTo(BuildRunState.PostChecking, ExportProgress, 1.0f, "PostChecking", "Verifying build artifacts");
            Log(BuildLogSeverity.Info, "PostChecking", $"Checking that the exported {request.ArtifactLabel} exists at the configured output path.");

            ThrowIfAbortRequested();

            PostCheckBuildOutputs(request);

            lock (_sync)
            {
                _outputDirectoryAbsolute = request.OutputDirectoryAbsolute;
                _outputFileAbsolute = request.OutputFileAbsolute;
            }

            Log(BuildLogSeverity.Success, "PostChecking", $"Build finished successfully: {request.OutputFileAbsolute}");
            Complete(BuildRunState.Succeeded, "Build complete", $"{request.ArtifactLabel} export finished successfully.");
        }
        catch (OperationCanceledException)
        {
            Complete(BuildRunState.Canceled, "Build canceled", "Build canceled. Partial outputs may remain in the target folder.");
        }
        catch (BuildFailureException ex)
        {
            Log(BuildLogSeverity.Error, "Failed", ex.Message);
            Complete(BuildRunState.Failed, "Build failed", ex.Message);
        }
        catch (Exception ex)
        {
            Log(BuildLogSeverity.Error, "Failed", ex.Message);
            Complete(BuildRunState.Failed, "Build failed", ex.Message);
        }
        finally
        {
            lock (_sync)
            {
                _activeProcess = null;
            }
        }
    }

    private ValidatedBuildRequest Validate(BuildProfileSnapshot profile, ExportPresetInfo? preset, string editorExecutablePath, string projectRootAbsolute)
    {
        TransitionTo(BuildRunState.Validating, 0.0f, ValidationProgress, "Validating", "Checking profile, export preset, templates, and output paths");

        if (!OperatingSystem.IsWindows())
        {
            throw new BuildFailureException("This v1 build flow currently supports Windows editor hosts only.");
        }

        var resolvedEditorExecutablePath = Path.GetFullPath(editorExecutablePath);
        if (!File.Exists(resolvedEditorExecutablePath))
        {
            throw new BuildFailureException($"The current Godot editor executable could not be found at '{resolvedEditorExecutablePath}'.");
        }

        var targetProject = GodotProjectInfo.Load(projectRootAbsolute);
        if (!File.Exists(targetProject.ProjectFileAbsolute))
        {
            throw new BuildFailureException("This folder does not look like a Godot project because project.godot is missing.");
        }

        if (string.IsNullOrWhiteSpace(profile.DisplayName))
        {
            throw new BuildFailureException("Build profile display name cannot be blank.");
        }

        if (string.IsNullOrWhiteSpace(profile.ExportPresetName))
        {
            throw new BuildFailureException("Build profile export preset name cannot be blank.");
        }

        SetProgress(0.04f);

        if (preset is null)
        {
            throw new BuildFailureException($"Export preset '{profile.ExportPresetName}' was not found in export_presets.cfg.");
        }

        if (!SupportedBuildPlatforms.TryResolveFromPreset(preset, out var platformInfo, out var platformError))
        {
            throw new BuildFailureException(platformError ?? $"Export preset '{preset.Name}' is not supported.");
        }

        SetProgress(0.08f);

        var outputDirectoryAbsolute = PathHelpers.ResolveDirectory(profile.OutputDirectory, targetProject.ProjectRootAbsolute);
        Directory.CreateDirectory(outputDirectoryAbsolute);

        var outputFileName = PathHelpers.EnsureOutputFileName(profile.ExecutableFileName, platformInfo.OutputFileExtension, platformInfo.ArtifactLabel);
        var outputFileAbsolute = Path.Combine(outputDirectoryAbsolute, outputFileName);

        lock (_sync)
        {
            _outputDirectoryAbsolute = outputDirectoryAbsolute;
            _outputFileAbsolute = outputFileAbsolute;
        }

        Log(BuildLogSeverity.Info, "Validating", $"Using build editor: {resolvedEditorExecutablePath}");
        Log(BuildLogSeverity.Info, "Validating", $"Using target Godot project: {targetProject.ProjectRootAbsolute}");
        Log(BuildLogSeverity.Info, "Validating", $"Using export preset '{preset.Name}' on platform '{preset.Platform}'.");
        Log(BuildLogSeverity.Info, "Validating", $"Resolved output path: {outputFileAbsolute}");

        SetProgress(0.11f);

        if (platformInfo.Platform == SupportedBuildPlatform.Web && targetProject.LooksLikeCSharpProject)
        {
            var csharpMarkers = new List<string>();
            if (targetProject.HasTopLevelCsproj)
            {
                csharpMarkers.Add("a top-level .csproj file");
            }

            if (targetProject.HasCSharpFeature)
            {
                csharpMarkers.Add("the C# project feature in project.godot");
            }

            var joinedMarkers = string.Join(" and ", csharpMarkers);
            throw new BuildFailureException($"Target project '{targetProject.ProjectRootAbsolute}' looks like a C# project because it contains {joinedMarkers}. Godot 4 cannot export C# projects to the Web, so Sea Shell DevTools only supports GDScript-only Web targets here.");
        }

        var editorVersionInfo = ResolveEditorVersionInfo(resolvedEditorExecutablePath);
        var templateDirectory = ResolveTemplateDirectory(editorVersionInfo);
        var matchingTemplates = FindMatchingTemplates(templateDirectory, platformInfo, profile.BuildMode);
        if (matchingTemplates.Count == 0)
        {
            var expectedTemplates = string.Join(", ", GetExpectedTemplateNames(platformInfo, profile.BuildMode));
            if (platformInfo.Platform == SupportedBuildPlatform.Web)
            {
                throw new BuildFailureException($"No compatible Web export templates were found for build editor '{resolvedEditorExecutablePath}' in '{templateDirectory}'. Sea Shell DevTools accepts {expectedTemplates}. Point Build Editor Override at a standard Godot editor with matching Web templates installed.");
            }

            throw new BuildFailureException($"Export templates for '{editorVersionInfo.NormalizedTemplateToken}' are installed, but the expected {platformInfo.ArtifactLabel} {(profile.BuildMode == BuildProfileBuildMode.Release ? "release" : "debug")} template is missing. Expected one of: {expectedTemplates}.");
        }

        Log(BuildLogSeverity.Success, "Validating", $"Found compatible export templates in '{templateDirectory}': {string.Join(", ", matchingTemplates.Select(Path.GetFileName))}");

        if (platformInfo.Platform == SupportedBuildPlatform.AndroidApk)
        {
            ValidateAndroidToolchain(editorVersionInfo.NormalizedTemplateToken);
            EnsureAndroidGradleBuildTemplate(templateDirectory, targetProject.ProjectRootAbsolute);
        }

        SetProgress(ValidationProgress);

        var shouldBuildSolution = profile.PrebuildDotnetSolution && targetProject.HasTopLevelCsproj;
        var buildSolutionSkipMessage = profile.PrebuildDotnetSolution
            ? "Skipping solution build because the active target project does not contain a top-level .csproj file."
            : "Skipping solution build because the active profile disabled it.";

        var buildSolutionArguments = CreateBuildSolutionArguments(targetProject.ProjectRootAbsolute, profile.VerboseGodotLog);
        var exportArguments = CreateExportArguments(targetProject.ProjectRootAbsolute, profile, outputFileAbsolute);

        return new ValidatedBuildRequest
        {
            Platform = platformInfo.Platform,
            ExportPresetName = profile.ExportPresetName,
            ArtifactLabel = platformInfo.ArtifactLabel,
            OutputDirectoryAbsolute = outputDirectoryAbsolute,
            OutputFileAbsolute = outputFileAbsolute,
            ShouldBuildSolution = shouldBuildSolution,
            BuildSolutionSkipMessage = buildSolutionSkipMessage,
            BuildSolutionArguments = buildSolutionArguments,
            ExportArguments = exportArguments,
        };
    }

    private void PostCheckBuildOutputs(ValidatedBuildRequest request)
    {
        if (!File.Exists(request.OutputFileAbsolute))
        {
            throw new BuildFailureException($"Godot reported a successful export, but the expected {request.ArtifactLabel} file was not found afterwards.");
        }

        if (request.Platform != SupportedBuildPlatform.Web)
        {
            return;
        }

        var outputStem = Path.GetFileNameWithoutExtension(request.OutputFileAbsolute);
        var sidecarFiles = Directory.GetFiles(request.OutputDirectoryAbsolute, $"{outputStem}*", SearchOption.TopDirectoryOnly)
            .Where(path => !path.Equals(request.OutputFileAbsolute, StringComparison.OrdinalIgnoreCase))
            .Select(Path.GetFileName)
            .OrderBy(static name => name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (sidecarFiles.Length == 0)
        {
            Log(BuildLogSeverity.Warning, "PostChecking", $"The Web HTML output exists, but no matching sidecar files were found beside '{Path.GetFileName(request.OutputFileAbsolute)}'.");
            return;
        }

        Log(BuildLogSeverity.Info, "PostChecking", $"Web sidecar files emitted beside '{Path.GetFileName(request.OutputFileAbsolute)}': {string.Join(", ", sidecarFiles)}");
    }

    private async Task RunProcessStepAsync(
        BuildRunState state,
        string stepId,
        string stepTitle,
        string detail,
        string executablePath,
        IReadOnlyList<string> arguments)
    {
        var phaseFloor = state == BuildRunState.BuildingSolution ? ValidationProgress : BuildProgress;
        var phaseCap = state == BuildRunState.BuildingSolution ? BuildProgress : ExportProgress;

        TransitionTo(state, phaseFloor, phaseCap, stepId, detail);
        Log(BuildLogSeverity.Info, stepId, $"{stepTitle} started.");
        Log(BuildLogSeverity.Info, stepId, $"Command: {FormatCommand(executablePath, arguments)}");

        ThrowIfAbortRequested();

        using var process = new Process();
        process.StartInfo = new ProcessStartInfo
        {
            FileName = executablePath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(executablePath) ?? Environment.CurrentDirectory,
        };

        foreach (var argument in arguments)
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        process.OutputDataReceived += (_, eventArgs) =>
        {
            if (eventArgs.Data is null)
            {
                return;
            }

            OnProcessOutput(stepId, eventArgs.Data, isErrorStream: false);
        };

        process.ErrorDataReceived += (_, eventArgs) =>
        {
            if (eventArgs.Data is null)
            {
                return;
            }

            OnProcessOutput(stepId, eventArgs.Data, isErrorStream: true);
        };

        lock (_sync)
        {
            _activeProcess = process;
        }

        if (!process.Start())
        {
            throw new BuildFailureException($"{stepTitle} could not be started.");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        await process.WaitForExitAsync();

        lock (_sync)
        {
            if (ReferenceEquals(_activeProcess, process))
            {
                _activeProcess = null;
            }
        }

        ThrowIfAbortRequested();

        if (process.ExitCode != 0)
        {
            throw new BuildFailureException($"{stepTitle} failed with exit code {process.ExitCode}. Check the step log for details.");
        }

        var completedProgress = state == BuildRunState.BuildingSolution ? BuildProgress : ExportProgress;
        SetProgress(completedProgress);
        Log(BuildLogSeverity.Success, stepId, $"{stepTitle} finished successfully.");
    }

    private void OnProcessOutput(string stepId, string rawLine, bool isErrorStream)
    {
        var line = StripAnsi(rawLine).Trim();
        if (string.IsNullOrWhiteSpace(line))
        {
            return;
        }

        var severity = ClassifySeverity(line, isErrorStream);
        Log(severity, stepId, line);
        NudgeProgress();

        lock (_sync)
        {
            _detail = line;
        }
    }

    private void TransitionTo(BuildRunState state, float phaseFloor, float phaseCap, string step, string detail)
    {
        lock (_sync)
        {
            _state = state;
            _phaseFloor = phaseFloor;
            _phaseCap = phaseCap;
            _phaseStartedUtc = DateTime.UtcNow;
            _currentStep = step;
            _detail = detail;
            _progress01 = Math.Max(_progress01, phaseFloor);
        }
    }

    private void SetProgress(float progress01)
    {
        lock (_sync)
        {
            _progress01 = Math.Clamp(progress01, 0.0f, 1.0f);
        }
    }

    private void NudgeProgress()
    {
        lock (_sync)
        {
            if (!IsEstimating(_state))
            {
                return;
            }

            _progress01 = Math.Min(_phaseCap, _progress01 + 0.01f);
        }
    }

    private void Complete(BuildRunState state, string step, string detail)
    {
        lock (_sync)
        {
            _state = state;
            _currentStep = step;
            _detail = detail;
            _progress01 = state == BuildRunState.Succeeded ? 1.0f : _progress01;
            _finishedUtc = DateTime.UtcNow;
        }

        switch (state)
        {
            case BuildRunState.Succeeded:
                Log(BuildLogSeverity.Success, step, detail);
                break;
            case BuildRunState.Canceled:
                Log(BuildLogSeverity.Warning, step, detail);
                break;
            default:
                Log(BuildLogSeverity.Error, step, detail);
                break;
        }
    }

    private void ThrowIfAbortRequested()
    {
        lock (_sync)
        {
            if (_abortRequested)
            {
                throw new OperationCanceledException();
            }
        }
    }

    private void Log(BuildLogSeverity severity, string step, string message)
    {
        _pendingLogs.Enqueue(new BuildLogEntry(DateTime.UtcNow, step, severity, message));
    }

    private static bool IsEstimating(BuildRunState state)
    {
        return state is BuildRunState.Validating or BuildRunState.BuildingSolution or BuildRunState.Exporting;
    }

    private static BuildLogSeverity ClassifySeverity(string line, bool isErrorStream)
    {
        if (line.Contains("error", StringComparison.OrdinalIgnoreCase))
        {
            return BuildLogSeverity.Error;
        }

        if (line.Contains("warning", StringComparison.OrdinalIgnoreCase))
        {
            return BuildLogSeverity.Warning;
        }

        if (isErrorStream)
        {
            return BuildLogSeverity.Warning;
        }

        return BuildLogSeverity.Info;
    }

    private static IReadOnlyList<string> CreateBuildSolutionArguments(string projectRootAbsolute, bool verbose)
    {
        var args = new List<string>
        {
            "--headless",
            "--path",
            projectRootAbsolute,
            "--build-solutions",
            "--quit",
        };

        if (verbose)
        {
            args.Insert(0, "--verbose");
        }

        return args;
    }

    private static IReadOnlyList<string> CreateExportArguments(string projectRootAbsolute, BuildProfileSnapshot profile, string outputFileAbsolute)
    {
        var args = new List<string>();
        if (profile.VerboseGodotLog)
        {
            args.Add("--verbose");
        }

        args.Add("--headless");
        args.Add("--path");
        args.Add(projectRootAbsolute);
        args.Add(profile.BuildMode == BuildProfileBuildMode.Release ? "--export-release" : "--export-debug");
        args.Add(profile.ExportPresetName);
        args.Add(outputFileAbsolute);
        return args;
    }

    private static EditorVersionInfo ResolveEditorVersionInfo(string editorExecutablePath)
    {
        using var process = new Process();
        process.StartInfo = new ProcessStartInfo
        {
            FileName = editorExecutablePath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        process.StartInfo.ArgumentList.Add("--version");

        process.Start();
        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        var combined = string.IsNullOrWhiteSpace(stdout) ? stderr : stdout;
        var firstLine = combined
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault()
            ?.Trim();

        if (string.IsNullOrWhiteSpace(firstLine))
        {
            throw new BuildFailureException("Could not determine the current Godot editor version during preflight validation.");
        }

        var match = Regex.Match(firstLine, @"^(?<token>\d+\.\d+\.[^.]+(?:\.mono)?)", RegexOptions.CultureInvariant);
        if (!match.Success)
        {
            throw new BuildFailureException($"Could not parse a Godot export template version from '{firstLine}'.");
        }

        return new EditorVersionInfo(firstLine, match.Groups["token"].Value);
    }

    private static string ResolveTemplateDirectory(EditorVersionInfo versionInfo)
    {
        var roaming = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var searchRoots = new[]
        {
            Path.Combine(roaming, "Godot", "export_templates"),
            Path.Combine(local, "Godot", "export_templates"),
        };

        foreach (var searchRoot in searchRoots)
        {
            if (!Directory.Exists(searchRoot))
            {
                continue;
            }

            foreach (var candidate in EnumerateTemplateDirectoryCandidates(searchRoot, versionInfo))
            {
                if (Directory.Exists(candidate))
                {
                    return candidate;
                }
            }

            foreach (var candidate in Directory.GetDirectories(searchRoot))
            {
                var directoryName = Path.GetFileName(candidate);
                if (directoryName.Equals(versionInfo.RawVersionLine, StringComparison.OrdinalIgnoreCase) ||
                    directoryName.Equals(versionInfo.NormalizedTemplateToken, StringComparison.OrdinalIgnoreCase))
                {
                    return candidate;
                }

                var versionFile = Path.Combine(candidate, "version.txt");
                if (!File.Exists(versionFile))
                {
                    continue;
                }

                var installedVersion = File.ReadAllText(versionFile).Trim();
                if (installedVersion.Equals(versionInfo.RawVersionLine, StringComparison.OrdinalIgnoreCase) ||
                    installedVersion.Equals(versionInfo.NormalizedTemplateToken, StringComparison.OrdinalIgnoreCase))
                {
                    return candidate;
                }
            }
        }

        throw new BuildFailureException($"Godot export templates for '{versionInfo.NormalizedTemplateToken}' were not found. Install matching templates for build editor '{versionInfo.RawVersionLine}' before exporting.");
    }

    private static IEnumerable<string> EnumerateTemplateDirectoryCandidates(string searchRoot, EditorVersionInfo versionInfo)
    {
        yield return Path.Combine(searchRoot, versionInfo.RawVersionLine);
        yield return Path.Combine(searchRoot, versionInfo.NormalizedTemplateToken);
    }

    private static IReadOnlyList<string> FindMatchingTemplates(string templateDirectory, SupportedBuildPlatformInfo platformInfo, BuildProfileBuildMode buildMode)
    {
        var patterns = buildMode == BuildProfileBuildMode.Release
            ? platformInfo.ReleaseTemplateSearchPatterns
            : platformInfo.DebugTemplateSearchPatterns;

        return patterns
            .SelectMany(pattern => Directory.GetFiles(templateDirectory, pattern, SearchOption.TopDirectoryOnly))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(static path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static IReadOnlyList<string> GetExpectedTemplateNames(SupportedBuildPlatformInfo platformInfo, BuildProfileBuildMode buildMode)
    {
        return buildMode == BuildProfileBuildMode.Release
            ? platformInfo.ReleaseTemplateSearchPatterns
            : platformInfo.DebugTemplateSearchPatterns;
    }

    private void ValidateAndroidToolchain(string versionToken)
    {
        var settingsPath = ResolveEditorSettingsPath(versionToken);
        if (!File.Exists(settingsPath))
        {
            throw new BuildFailureException($"Could not find Godot editor settings at '{settingsPath}' to validate Android export setup.");
        }

        var settings = ParseFlatSettingsFile(settingsPath);
        var androidSdkPath = Unquote(settings.GetValueOrDefault("export/android/android_sdk_path", "\"\""));
        var javaSdkPath = Unquote(settings.GetValueOrDefault("export/android/java_sdk_path", "\"\""));

        if (string.IsNullOrWhiteSpace(androidSdkPath))
        {
            throw new BuildFailureException("Godot Editor Settings > Export > Android > Android SDK Path is blank. Official Godot Android export setup requires an Android SDK path before exporting APKs.");
        }

        if (!Directory.Exists(androidSdkPath))
        {
            throw new BuildFailureException($"Godot's configured Android SDK Path does not exist: '{androidSdkPath}'.");
        }

        var adbPath = Path.Combine(androidSdkPath, "platform-tools", OperatingSystem.IsWindows() ? "adb.exe" : "adb");
        if (!File.Exists(adbPath))
        {
            throw new BuildFailureException($"Godot's configured Android SDK Path does not contain platform-tools/adb: '{androidSdkPath}'.");
        }

        if (string.IsNullOrWhiteSpace(javaSdkPath))
        {
            throw new BuildFailureException("Godot Editor Settings > Export > Android > Java SDK Path is blank. Official Godot Android export setup requires a Java SDK path before exporting APKs.");
        }

        if (!Directory.Exists(javaSdkPath) && !File.Exists(javaSdkPath))
        {
            throw new BuildFailureException($"Godot's configured Java SDK Path does not exist: '{javaSdkPath}'.");
        }

        Log(BuildLogSeverity.Success, "Validating", $"Found Android SDK at '{androidSdkPath}'.");
        Log(BuildLogSeverity.Success, "Validating", $"Found Java SDK path at '{javaSdkPath}'.");
    }

    private static string ResolveEditorSettingsPath(string versionToken)
    {
        var match = Regex.Match(versionToken, @"^(?<series>\d+\.\d+)", RegexOptions.CultureInvariant);
        if (!match.Success)
        {
            throw new BuildFailureException($"Could not determine the editor settings file for Godot version '{versionToken}'.");
        }

        var series = match.Groups["series"].Value;
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Godot", $"editor_settings-{series}.tres");
    }

    private static Dictionary<string, string> ParseFlatSettingsFile(string absolutePath)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var rawLine in File.ReadAllLines(absolutePath))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('[') || line.StartsWith(';') || line.StartsWith('#'))
            {
                continue;
            }

            var separatorIndex = line.IndexOf('=');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex].Trim();
            var value = line[(separatorIndex + 1)..].Trim();
            values[key] = value;
        }

        return values;
    }

    private static string Unquote(string rawValue)
    {
        var trimmed = rawValue.Trim();
        return trimmed.Length >= 2 && trimmed.StartsWith('"') && trimmed.EndsWith('"')
            ? trimmed[1..^1]
            : trimmed;
    }

    private void EnsureAndroidGradleBuildTemplate(string templateDirectory, string projectRootAbsolute)
    {
        var androidBuildDirectory = Path.Combine(projectRootAbsolute, "android", "build");
        var gradleBuildFile = Path.Combine(androidBuildDirectory, "build.gradle");
        if (File.Exists(gradleBuildFile))
        {
            Log(BuildLogSeverity.Success, "Validating", $"Found Android Gradle build template at '{androidBuildDirectory}'.");
            return;
        }

        var androidSourceZip = Path.Combine(templateDirectory, "android_source.zip");
        if (!File.Exists(androidSourceZip))
        {
            throw new BuildFailureException($"Android Gradle build support needs '{androidSourceZip}', but that template zip was not found.");
        }

        var androidRootDirectory = Path.Combine(projectRootAbsolute, "android");
        Directory.CreateDirectory(androidRootDirectory);

        if (Directory.Exists(androidBuildDirectory))
        {
            Directory.Delete(androidBuildDirectory, recursive: true);
        }

        ZipFile.ExtractToDirectory(androidSourceZip, androidBuildDirectory);
        Log(BuildLogSeverity.Success, "Validating", $"Installed Android Gradle build template into '{androidBuildDirectory}'.");
    }

    private static string FormatCommand(string executablePath, IReadOnlyList<string> arguments)
    {
        var builder = new StringBuilder();
        builder.Append(QuoteArgument(executablePath));
        foreach (var argument in arguments)
        {
            builder.Append(' ');
            builder.Append(QuoteArgument(argument));
        }

        return builder.ToString();
    }

    private static string QuoteArgument(string argument)
    {
        return argument.Contains(' ') ? $"\"{argument}\"" : argument;
    }

    private static string StripAnsi(string value)
    {
        return Regex.Replace(value, @"\x1B\[[0-9;]*[A-Za-z]", string.Empty);
    }

    private sealed class ValidatedBuildRequest
    {
        public required SupportedBuildPlatform Platform { get; init; }

        public required string ExportPresetName { get; init; }

        public required string ArtifactLabel { get; init; }

        public required string OutputDirectoryAbsolute { get; init; }

        public required string OutputFileAbsolute { get; init; }

        public required bool ShouldBuildSolution { get; init; }

        public required string BuildSolutionSkipMessage { get; init; }

        public required IReadOnlyList<string> BuildSolutionArguments { get; init; }

        public required IReadOnlyList<string> ExportArguments { get; init; }
    }

    private sealed record EditorVersionInfo(string RawVersionLine, string NormalizedTemplateToken);

    private sealed class BuildFailureException : Exception
    {
        public BuildFailureException(string message) : base(message)
        {
        }
    }
}
