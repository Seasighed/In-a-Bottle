using Godot;

namespace SeaShellDevTools;

[Tool]
public partial class SeaShellDevToolsPlugin : EditorPlugin
{
    private const int OpenDockId = 1;
    private const int BuildActiveProfileId = 2;
    private const string MenuName = "Sea Shell DevTools";

    private SeaShellDevToolsDock? _dock;
    private PopupMenu? _toolsMenu;

    public override void _EnterTree()
    {
        _dock = new SeaShellDevToolsDock();
        _dock.Initialize(this);
        AddDock(_dock);

        _toolsMenu = new PopupMenu();
        _toolsMenu.IdPressed += OnToolsMenuPressed;
        _toolsMenu.AddItem("Open Dock", OpenDockId);
        _toolsMenu.AddItem("Build Active Profile", BuildActiveProfileId);
        AddToolSubmenuItem(MenuName, _toolsMenu);
    }

    public override void _ExitTree()
    {
        RemoveToolMenuItem(MenuName);

        if (IsInstanceValid(_toolsMenu))
        {
            _toolsMenu?.QueueFree();
            _toolsMenu = null;
        }

        if (IsInstanceValid(_dock))
        {
            RemoveDock(_dock!);
            _dock?.QueueFree();
            _dock = null;
        }
    }

    private void OnToolsMenuPressed(long id)
    {
        switch (id)
        {
            case OpenDockId:
                _dock?.OpenDock();
                break;
            case BuildActiveProfileId:
                _dock?.BuildActiveProfileFromMenu();
                break;
        }
    }
}
