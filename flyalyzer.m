% Flyalyzer, Michael Rauscher 2019

function flyalyzer()
%% state variable declaration
    import java.awt.Robot;
    mouse = Robot;
    
    % declare color schemes
    %default scheme
    colorschemes(1).head = [0 0 255];
    colorschemes(1).abd = [255 0 255];
    colorschemes(1).wing = [0 255 0];
    colorschemes(1).halt = [255 0 0];
    colorschemes(1).axis = [0 255 255];
    colorschemes(1).name = 'Default';
    %monochrome green
    colorschemes(2).head = [0 255 0];
    colorschemes(2).abd = [0 255 0];
    colorschemes(2).wing = [0 255 0];
    colorschemes(2).halt = [0 255 0];
    colorschemes(2).axis = [0 255 0];
    colorschemes(2).name = 'Green';
    %monochrome amber
    colorschemes(3).head = [35 30 15];
    colorschemes(3).abd = [35 30 15];
    colorschemes(3).wing = [35 30 15];
    colorschemes(3).halt = [35 30 15];    
    colorschemes(3).axis = [35 30 15];
    colorschemes(3).name = 'Amber';
    %monochrome red
    colorschemes(4).head = [255 0 0];
    colorschemes(4).abd = [255 0 0];
    colorschemes(4).wing = [255 0 0];
    colorschemes(4).halt = [255 0 0];    
    colorschemes(4).axis = [255 0 0];
    colorschemes(4).name = 'Red';
    
    colors = colorschemes(1);
    
    state = struct;
    state.showdata = false;
    state.invertbw = false;
    
    state.vid.vreader = [];
    state.vid.vtimer = timer;
    state.vid.vtimer.Period = .001;
    state.vid.vtimer.TimerFcn = @nextframe;
    state.vid.vtimer.ExecutionMode = 'fixedSpacing';
    state.vid.vtimer.BusyMode = 'queue';
    state.vid.path = pwd;
    state.vid.basename = '';
    state.vid.ext = '';
    state.vid.fname = [];
    state.vid.ix = 1;
    state.vid.loop = false;
    
    state.track.ts = [];
    
    state.track.head.angle = [];
    state.track.head.root = [];
    state.track.head.mask = [];
    state.track.head.poly = [];
    state.track.head.thresh = .6;
    state.track.head.norm = 1;
    state.track.head.method = 2;
    state.track.head.offset = 30;
    state.track.head.extent = 15; 
    state.track.head.ltheta = 220;
    state.track.head.utheta = 320;
    state.track.head.npts = 30;    
    state.track.head.show.pts = true;
    state.track.head.show.thresh = false;
    state.track.head.show.poly = true;
    
    state.track.abd.angle = [];
    state.track.abd.root = [];
    state.track.abd.mask = [];
    state.track.abd.poly = [];
    state.track.abd.thresh = .8;
    state.track.abd.norm = 1;
    state.track.abd.method = 2;
    state.track.abd.offset = 50;
    state.track.abd.extent = 30; 
    state.track.abd.ltheta = 60;
    state.track.abd.utheta = 120;
    state.track.abd.npts = 50;    
    state.track.abd.show.pts = true;
    state.track.abd.show.thresh = false;
    state.track.abd.show.poly = true;
    
    state.track.wing.angle = [];  
    state.track.wing.root = [];
    state.track.wing.mask = [];
    state.track.wing.poly = [];
    state.track.wing.thresh = [.1 .1];
    state.track.wing.norm = 2;
    state.track.wing.offset = [80 80];
    state.track.wing.extent = [30 30]; 
    state.track.wing.ltheta = [150 275];
    state.track.wing.utheta = [265 390];
    state.track.wing.npts = [70 70];
    state.track.wing.lock = true;
    state.track.wing.show.pts = true;
    state.track.wing.show.thresh = true;
    state.track.wing.show.poly = true;    
    
%% ui figure init
    cf = figure('Name','Flyalyzer','NumberTitle','off',...
    'MenuBar','none','Resize','off','Position',[50 175 250 500],...
    'CloseRequestFcn',@closecleanup);

    vf = figure('Name','','NumberTitle','off','Visible','off',...
    'MenuBar','none','Resize','on','Position',[300 175 500 666],...
    'CloseRequestFcn',@closecleanup);
    state.vid.ax = gca;
    
    tf = figure('Name','Kinematic Trace','NumberTitle','off','Visible','off',...
    'MenuBar','none','Resize','off','Position',[966 175 500 500]);
    datax = axes(tf);
    lines = line(datax);

%% vidpanel and load button ui init

    exportbutton = uicontrol(cf,'Style','pushbutton','String',...
        'Export to Workspace','Position',[0 0 125 45],'Callback',@savedata);
    
    savebutton = uicontrol(cf,'Style','pushbutton','String',...
        'Save to Disk','Position',[125 0 125 45],'Callback',@savedata);

    loadbutton = uicontrol(cf,'Style','pushbutton','String',...
        'Load File','Position',[0 0 250 500],'Callback',@loadvid);
    
    vidpanel = uipanel(cf,'Title',' ','Units','pixels',...
        'Position',[63 430 187 70],'BorderType','none','Visible','off');
    
    playpause = uicontrol(vidpanel,'Style','pushbutton','String',...
        '>','Position',[2 28 30 40],...
        'Callback',@playctrl,'Interruptible','on');
    
    stopbutton = uicontrol(vidpanel,'Style','pushbutton','String',...
        '[]','Position',[32 28 20 40],...
        'Callback',@playctrl);
    
    dispframe = uicontrol(vidpanel,'Style', 'edit',...
        'String','','ButtonDownFcn',@playctrl,...
        'Position', [54 48 131 20],'Enable','off');
    
    progress = uicontrol(vidpanel,'Style','slider', 'Min',1,'Max',2,'Value',1,...
        'SliderStep',[1/(2-1) 1/(2-1)],...
        'Position',[54 28 131 20],'Callback',@playctrl);
    
    loopcheck = uicontrol(vidpanel,'Style', 'checkbox','String','Loop',...
        'Position', [3 3 50 20],'Callback',@playctrl);
    
    invertcheck = uicontrol(vidpanel,'Style', 'checkbox','String','Invert',...
        'Value',state.invertbw,'Position', [51 3 60 20],...
        'Callback',@updateacquisition);
    
    fpsdisplay = uicontrol(vidpanel,'Style','edit','Enable','off',...,
        'String',[],'Position',[102 2 80 20],'ButtonDownFcn',@updatefps);
    
%% acquisition tabs ui init

    setuppanel = uipanel('Parent', cf, 'Title', '','Visible','off',...
        'BorderType','none','Units','Pixels','Position',[0 283 250 145]); 
    tabs = uitabgroup('Parent', cf,'Units','Pixels','Visible','off',...
    'Position',[0 45 250 240]);
    tabstorage = uitabgroup('Parent',cf,'Visible','off');
       
    wingtab = uitab('Parent', tabstorage, 'Title', 'Wings');
    headtab = uitab('Parent', tabstorage, 'Title', 'Head');
    abdtab = uitab('Parent', tabstorage, 'Title', 'Abdomen');
    
%% acquisition control ui init
    
    axistitle = uicontrol(setuppanel,'Style', 'text','FontWeight','Bold',...
        'Position', [5 120 100 20],'String','Define Body Axis');    
    
    headroottext = uicontrol(setuppanel,'Style', 'text',...
        'Position', [5 100 60 20],'String','Head Root',...
        'HorizontalAlignment','right');
    headsetdisplay = uicontrol(setuppanel,'Style','edit','String',...
        [],'Position',[90 102 70 20],'Enable','off');
    
    headrootxadjust = uicontrol(setuppanel,'Style', 'slider','Value',0,...
        'Position', [70 102 20 19],'Enable','off','Callback',@updateacquisition);
    headrootyadjust = uicontrol(setuppanel,'Style', 'slider','Value',0,...
        'Position', [160 102 20 20],'Enable','off','Callback',@updateacquisition);    
    headptbutton = uicontrol(setuppanel,'Style','pushbutton','String',...
        'Pick','Position',[190 102 50 20],'Callback',@updateacquisition);
    
    abdroottext = uicontrol(setuppanel,'Style', 'text',...
        'Position', [5 80 60 20],'String','Abd. Root',...
        'HorizontalAlignment','right');
    abdsetdisplay = uicontrol(setuppanel,'Style','edit','String',...
        [],'Position',[90 82 70 20],'Enable','off');    
    abdrootxadjust = uicontrol(setuppanel,'Style', 'slider','Value',0,...
        'Position', [70 82 20 19],'Enable','off','Callback',@updateacquisition);
    abdrootyadjust = uicontrol(setuppanel,'Style', 'slider','Value',0,...
        'Position', [160 82 20 20],'Enable','off','Callback',@updateacquisition);
    abdptbutton = uicontrol(setuppanel,'Style','pushbutton','String',...
        'Pick','Position',[190 82 50 20],'Callback',@updateacquisition);
    
    trackpanel = uipanel(setuppanel,'Units','pixels','Title','Track Body Parts',...
        'FontWeight','bold','Position',[3 3 243 75],'Visible','off');
    
    tracktext = uicontrol(trackpanel,'Style', 'text',...
        'Position', [7 22 85 20],'String','Enable Tracking:',...
        'HorizontalAlignment','right');
    
    plottext = uicontrol(trackpanel,'Style', 'text',...
        'Position', [7 2 85 20],'String','Enable Plotting:',...
        'HorizontalAlignment','right');
    
    trackheadtext = uicontrol(trackpanel,'Style', 'text',...
        'Position', [105 40 50 20],'String','Head',...
        'HorizontalAlignment','left');
    trackheadcheck = uicontrol(trackpanel,'Style', 'checkbox',...
        'Position', [110 25 20 20],'Callback',@updateacquisition);
    plotheadcheck = uicontrol(trackpanel,'Style', 'checkbox',...
        'Position', [110 5 20 20],'Enable','off','Callback',@updateacquisition);
    
    trackwingtext = uicontrol(trackpanel,'Style', 'text',...
        'Position', [145 40 50 20],'String','Wings',...
        'HorizontalAlignment','left');
    trackwingcheck = uicontrol(trackpanel,'Style', 'checkbox',...
        'Position', [155 25 20 20],'Callback',@updateacquisition);
    plotwingcheck = uicontrol(trackpanel,'Style', 'checkbox',...
        'Position', [155 5 20 20],'Enable','off','Callback',@updateacquisition);
    
    trackabdtext = uicontrol(trackpanel,'Style', 'text',...
        'Position', [187 40 50 20],'String','Abdomen',...
        'HorizontalAlignment','left');    
    trackabdcheck = uicontrol(trackpanel,'Style', 'checkbox',...
        'Position', [200 25 20 20],'Callback',@updateacquisition);
    plotabdcheck = uicontrol(trackpanel,'Style', 'checkbox',...
        'Position', [200 5 20 20],'Enable','off','Callback',@updateacquisition);
    
%% wing tracking ui init

    leftwingtext = uicontrol(wingtab,'Style', 'text',...
        'Position', [33 190 70 20],'String','Left Wing',...
        'FontWeight','bold','HorizontalAlignment','left');
    
    rightwingtext = uicontrol(wingtab,'Style', 'text',...
        'Position', [158 190 70 20],'String','Right Wing',...
        'FontWeight','bold','HorizontalAlignment','left');
    
    
    wingnormdropdown = uicontrol(wingtab,'Style','popupmenu','String',...
        {'no norm','ROI norm','Full norm'},'Tooltip','Histogram Normalization Options',...
        'Value',state.track.wing.norm,'Position',[3 7 70 17],...
        'Callback',@updatewingtracking);
    
    overlaywingscheck = uicontrol(wingtab,'Style','checkbox','String',...
        'BW','Value',state.track.wing.show.thresh,'Tooltip','Overlay Thresholded ROI',...
        'Position', [80 3 60 20],'Callback',@updatewingtracking);
    
    lockwingscheck = uicontrol(wingtab,'Style', 'checkbox','String',...
        'Sync','Value',state.track.wing.lock,'Tooltip','Sync Left and Right Wing Settings',...
        'Position', [130 3 60 20],'Callback',@updatewingtracking);
    
    clearwingsbutton = uicontrol(wingtab,'Style','pushbutton','String',...
        'Clear Data','Position',[180 1 63 24],'Callback',@updateacquisition);
        
    wingap1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',25,'Position', [3 173 20 20],...
        'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
        'Callback',@updatewingtracking);
    wingap2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',25,'Position', [128 173 20 20],...
        'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
        'Callback',@updatewingtracking);
    wingap1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(wingap1adjust.Value) '% rootAP'],...
        'Position',[23 173 95 20],'Enable','off');
    wingap2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(wingap2adjust.Value) '% rootAP'],...
        'Position',[148 173 95 20],'Enable','off');
    
    wingml1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',50,'Position', [3 152 20 19],...
        'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
        'Callback',@updatewingtracking);
    wingml2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',50,'Position', [128 152 20 19],...
        'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
        'Callback',@updatewingtracking);
    wingml1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(wingml1adjust.Value) '% rootML'],...
        'Position',[23 152 95 20],'Enable','off');
    wingml2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(wingml2adjust.Value) '% rootML'],...
        'Position',[148 152 95 20],'Enable','off');
    
    
    wingt1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.thresh(1)*100) '% thresh'],...
        'Position',[23 131 95 20],'Enable','off');
    wingt2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.thresh(2)*100) '% thresh'],...
        'Position',[148 131 95 20],'Enable','off');    
    wingt1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.thresh(1),'Position', [3 131 20 20],...
        'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
        'Callback',@updatewingtracking);
    wingt2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.thresh(2),'Position', [128 131 20 20],...
        'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
        'Callback',@updatewingtracking);
    
    wingo1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.offset(1)) 'px offset'],...
        'Position',[23 110 95 20],'Enable','off');
    wingo2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.offset(2)) 'px offset'],...
        'Position',[148 110 95 20],'Enable','off');    
    wingo1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.offset(1),'Position', [3 110 20 20],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updatewingtracking);
    wingo2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.offset(2),'Position', [128 110 20 20],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updatewingtracking);
    
    winge1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.extent(1)) 'px extent'],...
        'Position',[23 89 95 20],'Enable','off');
    winge2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.extent(2)) 'px extent'],...
        'Position',[148 89 95 20],'Enable','off');
    winge1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.extent(1),'Position', [3 89 20 20],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updatewingtracking);
    winge2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.extent(2),'Position', [128 89 20 20],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updatewingtracking);
    
    wingn1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.npts(1)) 'px tracked'],...
        'Position',[23 68 95 20],'Enable','off');
    wingn2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(state.track.wing.npts(2)) 'px tracked'],...
        'Position',[148 68 95 20],'Enable','off');    
    wingn1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.npts(1),'Position', [3 68 20 20],...
        'Min',0,'Max',400,'SliderStep',[1/400, 1/40],...
        'Callback',@updatewingtracking);
    wingn2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.npts(2),'Position', [128 68 20 20],...
        'Min',0,'Max',400,'SliderStep',[1/400, 1/40],...
        'Callback',@updatewingtracking);
    
    wingl1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(360-state.track.wing.ltheta(1)) '° lower'],...
        'Position',[23 47 95 20],'Enable','off');
    wingu2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(wrapTo360(360-state.track.wing.utheta(2))) '° upper'],...
        'Position',[148 47 95 20],'Enable','off');    
    wingl1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.ltheta(1),'Position', [3 47 20 20],...
        'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
        'Callback',@updatewingtracking);
    wingu2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.utheta(2)-360,'Position', [128 47 20 20],...
        'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
        'Callback',@updatewingtracking);    
    
    wingu1setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(360-state.track.wing.utheta(1)) '° upper'],...
        'Position',[23 26 95 20],'Enable','off');
    wingl2setdisplay = uicontrol(wingtab,'Style','edit','String',...
        [num2str(360-state.track.wing.ltheta(2)) '° lower'],...
        'Position',[148 26 95 20],'Enable','off');    
    wingu1adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.utheta(1),'Position', [3 26 20 20],...
        'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
        'Callback',@updatewingtracking);
    wingl2adjust = uicontrol(wingtab,'Style', 'slider',...
        'Value',state.track.wing.ltheta(2),'Position', [128 26 20 20],...
        'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
        'Callback',@updatewingtracking);

%% head tracking ui init 

    headmethodtext = uicontrol(headtab,'Style','text','FontWeight','Bold',...
        'Position', [154 174 90 30],'String','Tip-Tracking Method');

    headmethoddropdown = uicontrol(headtab,'Style','popupmenu','String',...
        {'distribution','k-means'},'Value',state.track.head.method,...
        'Position',[159 151 80 22],'Callback',@updateheadtracking);
    
    headnormtext = uicontrol(headtab,'Style', 'text','FontWeight','Bold',...
        'Position', [154 109 90 30],'String','Histogram Normalization');

    headnormdropdown = uicontrol(headtab,'Style','popupmenu','String',...
        {'none','ROI only','full image'},'Value',state.track.head.norm,...
        'Position',[159 86 80 22],'Callback',@updateheadtracking);
    
    overlayheadcheck = uicontrol(headtab,'Style','checkbox','String',...
        'Overlay BW','Value',state.track.head.show.thresh,...,
        'Tooltip','Overlay Thresholded ROI',...
        'Position', [159 64 80 20],'Callback',@updateheadtracking);
    
    clearheadbutton = uicontrol(headtab,'Style','pushbutton','String',...
        'Clear Data','Position',[159 6 80 50],'Callback',@updateacquisition);

    headtsetdisplay = uicontrol(headtab,'Style','edit','String',...
        [num2str(state.track.head.thresh*100) '% thresh'],...
        'Position',[33 176 120 30],'Enable','off');
    headtadjust = uicontrol(headtab,'Style', 'slider',...
        'Value',state.track.head.thresh,'Position', [3 176 30 30],...
        'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
        'Callback',@updateheadtracking);
    
    headosetdisplay = uicontrol(headtab,'Style','edit','String',...
        [num2str(state.track.head.offset) 'px offset'],...
        'Position',[33 142 120 30],'Enable','off');
    headoadjust = uicontrol(headtab,'Style', 'slider',...
        'Value',state.track.head.offset,'Position', [3 142 30 30],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updateheadtracking);
    
    headesetdisplay = uicontrol(headtab,'Style','edit','String',...
        [num2str(state.track.head.extent) 'px extent'],...
        'Position',[33 108 120 30],'Enable','off');
    headeadjust = uicontrol(headtab,'Style', 'slider',...
        'Value',state.track.head.extent,'Position', [3 108 30 30],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updateheadtracking);
    
    headnsetdisplay = uicontrol(headtab,'Style','edit','String',...
        [num2str(state.track.head.npts) 'px tracked'],...
        'Position',[33 74 120 30],'Enable','off');
    headnadjust = uicontrol(headtab,'Style', 'slider',...
        'Value',state.track.head.npts,'Position', [3 74 30 30],...
        'Min',0,'Max',400,'SliderStep',[1/400, 1/40],...
        'Callback',@updateheadtracking);
    
    headlsetdisplay = uicontrol(headtab,'Style','edit','String',...
        [num2str(360-state.track.head.ltheta) '° lower'],...
        'Position',[33 40 120 30],'Enable','off');
    headladjust = uicontrol(headtab,'Style', 'slider',...
        'Value',state.track.head.ltheta,'Position', [3 40 30 30],...
        'Min',180,'Max',270,'SliderStep',[1/90, 1/90],...
        'Callback',@updateheadtracking);
    
    headusetdisplay = uicontrol(headtab,'Style','edit','String',...
        [num2str(360-state.track.head.utheta) '° upper'],...
        'Position',[33 6 120 30],'Enable','off');
    headuadjust = uicontrol(headtab,'Style', 'slider',...
        'Value',state.track.head.utheta,'Position', [3 6 30 30],...
        'Min',270,'Max',360,'SliderStep',[1/90, 1/9],...
        'Callback',@updateheadtracking);
%% abdomen tracking ui init   
    
    abdnormtext = uicontrol(abdtab,'Style', 'text','FontWeight','Bold',...
        'Position', [154 174 90 30],'String','Histogram Normalization');

    abdnormdropdown = uicontrol(abdtab,'Style','popupmenu','String',...
        {'none','ROI only','full image'},'Value',state.track.abd.norm,...
        'Position',[159 151 80 22],'Callback',@updateabdtracking);
    
    overlayabdcheck = uicontrol(abdtab,'Style','checkbox','String',...
        'Overlay BW','Value',state.track.abd.show.thresh,...,
        'Tooltip','Overlay Thresholded ROI',...
        'Position', [159 129 80 20],'Callback',@updateabdtracking);
    
    clearabdbutton = uicontrol(abdtab,'Style','pushbutton','String',...
        'Clear Data','Position',[159 6 80 50],'Callback',@updateacquisition);

    abdtsetdisplay = uicontrol(abdtab,'Style','edit','String',...
        [num2str(state.track.abd.thresh*100) '% thresh'],...
        'Position',[33 176 120 30],'Enable','off');
    abdtadjust = uicontrol(abdtab,'Style', 'slider',...
        'Value',state.track.abd.thresh,'Position', [3 176 30 30],...
        'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
        'Callback',@updateabdtracking);
    
    abdosetdisplay = uicontrol(abdtab,'Style','edit','String',...
        [num2str(state.track.abd.offset) 'px offset'],...
        'Position',[33 142 120 30],'Enable','off');
    abdoadjust = uicontrol(abdtab,'Style', 'slider',...
        'Value',state.track.abd.offset,'Position', [3 142 30 30],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updateabdtracking);
    
    abdesetdisplay = uicontrol(abdtab,'Style','edit','String',...
        [num2str(state.track.abd.extent) 'px extent'],...
        'Position',[33 108 120 30],'Enable','off');
    abdeadjust = uicontrol(abdtab,'Style', 'slider',...
        'Value',state.track.abd.extent,'Position', [3 108 30 30],...
        'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
        'Callback',@updateabdtracking);
    
    abdnsetdisplay = uicontrol(abdtab,'Style','edit','String',...
        [num2str(state.track.abd.npts) 'px tracked'],...
        'Position',[33 74 120 30],'Enable','off');
    abdnadjust = uicontrol(abdtab,'Style', 'slider',...
        'Value',state.track.abd.npts,'Position', [3 74 30 30],...
        'Min',0,'Max',1000,'SliderStep',[1/1000, 1/100],...
        'Callback',@updateabdtracking);
    
    abdlsetdisplay = uicontrol(abdtab,'Style','edit','String',...
        [num2str(360-state.track.abd.ltheta) '° lower'],...
        'Position',[33 40 120 30],'Enable','off');
    abdladjust = uicontrol(abdtab,'Style', 'slider',...
        'Value',state.track.abd.ltheta,'Position', [3 40 30 30],...
        'Min',0,'Max',90,'SliderStep',[1/90, 1/90],...
        'Callback',@updateabdtracking);
    
    abdusetdisplay = uicontrol(abdtab,'Style','edit','String',...
        [num2str(360-state.track.abd.utheta) '° upper'],...
        'Position',[33 6 120 30],'Enable','off');
    abduadjust = uicontrol(abdtab,'Style', 'slider',...
        'Value',state.track.abd.utheta,'Position', [3 6 30 30],...
        'Min',90,'Max',180,'SliderStep',[1/90, 1/9],...
        'Callback',@updateabdtracking);    

%% main support functions

    function nextframe(~,~)
        if (state.vid.ix+1)>state.vid.nframes
            if state.vid.loop
                setframeix(1);
            else
                stop(state.vid.vtimer);
                playpause.String = '>';
            end
        else
            setframeix(state.vid.ix+1);
        end
    end

    function setframeix(ix)
        %if the requested frame is the next frame we can just read the next
        %frame, so we'll only set the video time if we need to
        if ix~=(state.vid.ix+1)
            state.vid.vreader.CurrentTime = state.vid.timeix(ix);
        end
        state.vid.ix = ix;
        state.vid.curframe = readFrame(state.vid.vreader);
        progress.Value = ix;
        dispframe.String = ['Frame ' num2str(ix) ' of ' num2str(state.vid.nframes)];
        processframe();
        showframe();
        plotdata();
    end
    function processframe()
        img = state.vid.curframe;
        if state.invertbw;img = imcomplement(img);end        
        out = img;
        if ~isempty(state.track.abd.root) && ~isempty(state.track.head.root)      
            wing = state.track.wing;
            head = state.track.head;
            abd = state.track.abd;
            
            %draw body axis
            angle = state.track.orientation;
            r = sqrt(state.vid.width^2 + state.vid.height^2);
            pt1(1) = head.root(1)-r*sind(angle);
            pt1(2) = head.root(2)+r*cosd(angle);
            pt2(1) = abd.root(1)+r*sind(angle);
            pt2(2) = abd.root(2)-r*cosd(angle);
            insline = [pt1 pt2];
            out = insertShape(out,'Line',insline,'color',colors.axis);
            
            % wing tracking
            if trackwingcheck.Value && ~isempty(state.track.wing.poly)
                [angle1,pts1,bw1] = trackborder(img,wing.mask(:,:,1),wing.root(1,:),wing.thresh(1),wing.norm,wing.npts(1),'lower');
                angle1 = wrapTo360(angle1);
                r = wing.extent(1)+wing.offset(1);
                pt2(1) = wing.root(1,1)+r*cosd(angle1);
                pt2(2) = wing.root(1,2)+r*sind(angle1);
                insline = [wing.root(1,:) pt2];
                [angle2,pts2,bw2] = trackborder(img,wing.mask(:,:,2),wing.root(2,:),wing.thresh(2),wing.norm,wing.npts(2),'upper');
                angle2 = wrapTo360(angle2);
                r = wing.extent(2)+wing.offset(2);
                pt2(1) = wing.root(2,1)+r*cosd(angle2);
                pt2(2) = wing.root(2,2)+r*sind(angle2);
                insline = [insline; wing.root(2,:) pt2];            
                
                %record values (switch from y-inverted computer graphics
                %coordinates to conventional coordinates)
                state.track.wing.angle(1:2,state.vid.ix) = [360-angle1;360-angle2];
                
                % draw thresh
                if wing.show.thresh
                    out = overlaythresh(out,colors.wing./2,bw1);
                    out = overlaythresh(out,colors.wing./2,bw2);
                end
                
                if ~any(isnan(insline))
                    out = insertShape(out,'Line',insline,'color',colors.wing);
                    if wing.show.pts
                        out = insertMarker(out,pts1,'+','color',colors.wing);
                        out = insertMarker(out,pts2,'+','color',colors.wing);
                    end
                end
                if wing.show.poly
                    out = insertShape(out,'Polygon',wing.poly,'color',colors.wing);
                end
            end
            
            if trackheadcheck.Value && ~isempty(state.track.head.poly)
                
                [angle, pts,bw] = tracktip(img,head.mask,head.root,head.thresh,head.norm,head.npts,head.method);
                angle = wrapTo360(angle);
                r = head.extent+head.offset;
                pt2(1) = head.root(1)+r*cosd(angle);
                pt2(2) = head.root(2)+r*sind(angle);
                insline = [head.root pt2];
                r = .66*r;
                pt3(1) = head.root(1)+r*cosd(90+angle);
                pt3(2) = head.root(2)+r*sind(90+angle);
                pt4(1) = head.root(1)+r*cosd(angle-90);
                pt4(2) = head.root(2)+r*sind(angle-90);
                insline = [insline;head.root pt3;head.root pt4];
                
                %record value (switch from y-inverted computer graphics
                %coordinates to conventional coordinates)
                    state.track.head.angle(state.vid.ix)=360-angle;
                
                if head.show.thresh
                    out = overlaythresh(out,colors.head./2,bw);
                end
                
                if ~any(isnan(insline))
                    out = insertShape(out,'Line',insline,'color',colors.head);
                    if head.show.pts
                        out = insertMarker(out,pts,'+','color',colors.head);
                    end
                end
                if head.show.poly
                    out = insertShape(out,'Polygon',head.poly,'color',colors.head);
                end
            end
            if trackabdcheck.Value && ~isempty(state.track.abd.poly)                
                [angle,pts,bw] = tracktip(img,abd.mask,abd.root,abd.thresh,abd.norm,abd.npts,abd.method,1);
                angle = wrapTo360(angle);
                r = abd.extent+abd.offset;
                pt2(1) = abd.root(1)+r*cosd(angle);
                pt2(2) = abd.root(2)+r*sind(angle);
                insline = [abd.root pt2];
                
                %record value (switch from y-inverted computer graphics
                %coordinates to conventional coordinates)
                state.track.abd.angle(state.vid.ix) = 360-angle;
                
                if abd.show.thresh
                    out = overlaythresh(out,colors.abd./2,bw);
                end
                
                if ~any(isnan(insline))
                    out = insertShape(out,'Line',insline,'color',colors.abd);
                    if abd.show.pts
                        out = insertMarker(out,pts,'+','color',colors.abd);
                    end
                end
                if abd.show.poly
                    out = insertShape(out,'Polygon',state.track.abd.poly,'color',colors.abd);
                end
            end
        end
        if ~isempty(state.track.head.root)
            out = insertMarker(out,state.track.head.root,'s','color',colors.head);            
        end
        if ~isempty(state.track.abd.root)
            out = insertMarker(out,state.track.abd.root,'s','color',colors.abd);
        end
        if ~isempty(state.track.wing.root) && trackwingcheck.Value
            out = insertMarker(out,state.track.wing.root,'s','color',colors.wing);
        end
        state.vid.dispframe = out;
    end    
    function showframe()        
        imagesc(state.vid.ax,state.vid.dispframe);
        set(state.vid.ax,'TickLength',[0 0]);
    end
%% program and play control functions
    function closecleanup(~,~)
        stop(state.vid.vtimer);
        drawnow;
        try delete(vf);catch;end
        try delete(tf);catch;end
        closereq
    end

    function savedata(b,~)
        fly = struct;
        fly.vidfilename = [state.vid.basename state.vid.ext];
        fly.numframes = state.vid.nframes;
        fly.duration = state.vid.nframes/state.vid.fps;
        fly.fps = state.vid.fps;
        fly.timestamps = state.track.ts;
        if trackheadcheck.Value
            fly.head = state.track.head.angle;
        end
        if trackwingcheck.Value
            fly.wingL=state.track.wing.angle(1,:);
            fly.wingR=state.track.wing.angle(2,:);
        end
        if trackabdcheck.Value
            fly.abd = state.track.abd.angle;
        end
        if isfield(state.track,'orientation')
            %transform appropriately (abdroot->headroot)
            fly.bodyorientation = 360-(wrapTo360(state.track.orientation-90));
        end
            
        switch b
            case exportbutton
                assignin('base','fly',fly);
            case savebutton
                savefilename = [fullfile(state.vid.path,state.vid.basename) '_PROC'];
%                 savefilename = [savefilename '_flyalyzer' datestr(now,'_yyyymm_hhMMSS_PROC')];
                save(savefilename,'fly')
        end
    end

    function loadvid(~,~)
        [fname,pname,fix] = uigetfile({'*.avi;*.mp4'},'Select Video file');
        if fix ~= 0
            if strcmp(state.vid.vtimer.Running,'on') 
                stop(state.vid.vtimer);
                playpause.String = '>';
            end
            state.vid.path = pname;
            [~,state.vid.basename,state.vid.ext] = fileparts(fname);
            vr = VideoReader(fullfile(pname,fname));
            
            f = 0;
            timeix = [];
            numframes = 0;
%             fprintf('Building Frame Index...');
            while hasFrame(vr)
                f = f+1;
                timeix(f) = vr.CurrentTime;
                numframes = numframes+1;
                readFrame(vr);
            end
            progress.Max = numframes;
            progress.SliderStep = [1/(numframes-1) 1/(numframes-1)];
            
            state.vid.vreader = vr;
            state.vid.timeix = timeix;
            state.vid.nframes = numframes;
            state.vid.width = vr.Width;
            state.vid.height = vr.Height;
            fps = round(vr.FrameRate);%give an even integer
            state.vid.fps = fps;
            vr.CurrentTime = timeix(1);
            state.vid.curframe = readFrame(vr);
            state.vid.dispframe = state.vid.curframe;
            vr.CurrentTime = timeix(1);
            set(fpsdisplay,'String',[num2str(state.vid.fps) 'FPS']);
            pos = vf.Position;            
            pos(4) = 500;
            pos(3) = 500*state.vid.width/state.vid.height;
            vf.Name = state.vid.basename;
            vf.Position = pos;
            vf.Visible = 'on';
            state.vid.ax.Position = [0 0 1 1];
            
            trackwingcheck.Value = false;
            trackheadcheck.Value = false;
            trackabdcheck.Value = false;
            updateacquisition(trackwingcheck,[]);
            updateacquisition(trackheadcheck,[]);
            updateacquisition(trackabdcheck,[]);
            updatewingtracking(lockwingscheck,[]);
            
            vidpanel.Visible = 'on';
            setuppanel.Visible = 'on';
            set(loadbutton,'Position',[3 432 60 65]);
            set(headrootxadjust,'Min',0,'Max',state.vid.width,'Value',0,...
                'SliderStep',[1/state.vid.width 10/state.vid.width]);
            set(headrootyadjust,'Min',0,'Max',state.vid.height,'Value',0,...
                'SliderStep',[1/state.vid.width 10/state.vid.height]);
            set(abdrootxadjust,'Min',0,'Max',state.vid.width,'Value',0,...
                'SliderStep',[1/state.vid.width 10/state.vid.width]);
            set(abdrootyadjust,'Min',0,'Max',state.vid.height,'Value',0,...
                'SliderStep',[1/state.vid.width 10/state.vid.height]);
            headsetdisplay.String = '';
            abdsetdisplay.String = '';
            
            trackpanel.Visible = 'off';

            state.track.wing.angle = nan(2,numframes);
            state.track.head.angle = nan(1,numframes);
            state.track.abd.angle = nan(1,numframes);
            state.track.ts = linspace(0,numframes/fps,numframes);
            state.track.head.root = [];
            state.track.abd.root = [];
            state.showdata = false;
            if strcmp(tf.Visible,'on');tf.Visible = 'off';end
            setframeix(1);

        end
    end
    function playctrl(h,e)
        switch h
            case dispframe
                value = inputdlg('Pick Frame:','',[1,30],{num2str(state.vid.ix)});
                if ~isempty(value) && all(isstrprop(strip(value{1}),'digit'))
                    value = str2num(value{1});
                    if value>0 && value<= state.vid.nframes
                        setframeix(value);
                    else
                        return
                    end
                else
                    return
                end
            case stopbutton
                stop(state.vid.vtimer)
                setframeix(1);
            case playpause
                if strcmp(state.vid.vtimer.Running,'off')
                    if progress.Value == progress.Max && ~state.vid.loop
                        setframeix(1);
                    else
                        start(state.vid.vtimer);                                            
                    end
                else
                    stop(state.vid.vtimer);
                end
            case progress
                setframeix(round(progress.Value));
            case {datax,lines}
                if ~strcmp(e.EventName,'Hit');return;end
                ix=e.IntersectionPoint(1);
                ix = floor(ix*state.vid.fps);
                if ix<1;ix = 1;end
                if ix>state.vid.nframes;ix = state.vid.nframes;end
                setframeix(ix);
            case loopcheck
                state.vid.loop = h.Value;
        end
        if strcmp(state.vid.vtimer.Running,'on')
            playpause.String = '||';
        else
            playpause.String = '>';    
        end
    end
%% acquisition control functions
    function updateacquisition(a,~)
       c = {trackwingcheck,trackheadcheck,trackabdcheck};
       p = {plotwingcheck,plotheadcheck,plotabdcheck};
       t = {wingtab,headtab,abdtab};
       tabchanged = false;
       switch a
           case c
               tabchanged = true;
               ix = find([c{:}]==a);
               if a.Value
                   p{ix}.Enable = 'On';
               else
                   p{ix}.Enable = 'Off';
                   p{ix}.Value = false;
               end
               updateacquisition(p{ix},[]);
           case p
               b = 0;
               for i = 1:length(p)
                   b = b | p{i}.Value;
               end
               if b
                   state.showdata = true;
               else
                   state.showdata = false;
                   tf.Visible = 'Off';
               end
           case invertcheck
               state.invertbw = a.Value;
           case headptbutton
               state.track.head.root=pickpt(1);
           case headrootxadjust
               hr = state.track.head.root;
               hr(1) = int16(a.Value);
               state.track.head.root = hr;
           case headrootyadjust
               hr = state.track.head.root;
               hr(2) = int16(state.vid.height-a.Value);
               state.track.head.root = hr;
           case abdrootxadjust
               ar = state.track.abd.root;
               ar(1) = int16(a.Value);
               state.track.abd.root = ar;
           case abdrootyadjust
               ar = state.track.abd.root;
               ar(2) = int16(state.vid.height-a.Value);
               state.track.abd.root = ar;
           case abdptbutton
               state.track.abd.root=pickpt(1); 
           case clearheadbutton
              trackheadcheck.Value = false;
              updateacquisition(trackheadcheck,[]);
              state.track.head.angle = nan(1,state.vid.nframes);
           case clearabdbutton
              trackabdcheck.Value = false;
              updateacquisition(trackabdcheck,[]);
              state.track.abd.angle = nan(1,state.vid.nframes);
           case clearwingsbutton
              trackwingcheck.Value = false;
              updateacquisition(trackwingcheck,[]);
              state.track.wing.angle = nan(2,state.vid.nframes);
           otherwise
               disp('!');
       end
       %figure out tabs
        if tabchanged
            for i = 1:3
               set(t{i},'Parent',tabstorage);
               if c{i}.Value
                   set(t{i},'Parent',tabs);
               end
            end
            if a.Value
                tabs.SelectedTab = t{ix};
            end
        end
        updatetracking();
    end
    function updatefps(~,~)
            defaultfps = round(state.vid.vreader.FrameRate);
            message = ['Input FPS: (from file: ' num2str(defaultfps) ')'];
%             message = sprintf(message);
            value = inputdlg(message,'',[1,30],{num2str(state.vid.fps)});
            if ~isempty(value) && all(isstrprop(strip(value{1}),'digit'))
                value = str2num(value{1});
                if value>0
                    state.vid.fps = value;
                    fpsdisplay.String = [num2str(value) 'FPS'];
                else
                    return
                end
            else
                return
            end
    end
%% wing tracking ui functions
    function updatewingtracking(w,~)
        
        if  any([wingl1adjust,wingl2adjust,wingu1adjust,wingu2adjust]==w)
            boundschanged = true;
            
            %kludge to let us wrap past 0/360 
            if w.Value == -1
                w.Value = 359;
            elseif w.Value == 360
                w.Value = 0;
            end
            
        else
            boundschanged = false;
        end
        
        switch w
            case overlaywingscheck
                state.track.wing.show.thresh = w.Value;
            case lockwingscheck
                state.track.wing.lock = w.Value;
                if state.track.wing.lock
                    enset = 'off';
                    tosync = {wingml1adjust,wingap1adjust,wingt1adjust,...
                      wingo1adjust,winge1adjust,wingn1adjust,...
                      wingu1adjust,wingl1adjust};
                    for ix = 1:length(tosync)
                        updatewingtracking(tosync{ix},[]);
                    end
                else
                    enset = 'on';                    
                end
                wingap2adjust.Enable = enset;
                wingml2adjust.Enable = enset;
                wingt2adjust.Enable = enset;
                wingo2adjust.Enable = enset;
                winge2adjust.Enable = enset;
                wingn2adjust.Enable = enset;
                wingu2adjust.Enable = enset;
                wingl2adjust.Enable = enset;
                
            case wingnormdropdown
                state.track.wing.norm = w.Value;
            case wingml1adjust
                ml = w.Value;
                wingml1setdisplay.String = [num2str(ml) '% rootML'];
                if state.track.wing.lock
                    wingml2adjust.Value = ml;
                    wingml2setdisplay.String = [num2str(ml) '% rootML'];
                end
            case wingml2adjust
                wingml2setdisplay.String = [num2str(w.Value) '% rootML'];
            case wingap1adjust
                ap = w.Value;
                wingap1setdisplay.String = [num2str(ap) '% rootAP'];
                if state.track.wing.lock
                    wingap2adjust.Value = ap;
                    wingap2setdisplay.String = [num2str(ap) '% rootAP'];
                end
            case wingap2adjust
                wingap2setdisplay.String = [num2str(w.Value) '% rootAP'];
            case wingt1adjust
                state.track.wing.thresh(1) = w.Value;
                if state.track.wing.lock 
                    state.track.wing.thresh(2) = w.Value;
                    wingt2adjust.Value = w.Value;
                    wingt2setdisplay.String = [num2str(state.track.wing.thresh(2)*100) '% thresh'];
                end
                wingt1setdisplay.String = [num2str(state.track.wing.thresh(1)*100) '% thresh'];
            case wingt2adjust
                state.track.wing.thresh(2) = w.Value;
                wingt2setdisplay.String = [num2str(state.track.wing.thresh(2)*100) '% thresh'];
            case wingo1adjust
                state.track.wing.offset(1) = w.Value;
                if state.track.wing.lock 
                    state.track.wing.offset(2) = w.Value;
                    wingo2adjust.Value = w.Value;
                    wingo2setdisplay.String = [num2str(state.track.wing.offset(2)) 'px offset'];
                end
                wingo1setdisplay.String = [num2str(state.track.wing.offset(1)) 'px offset'];
            case wingo2adjust
                state.track.wing.offset(2) = w.Value;
                wingo2setdisplay.String = [num2str(state.track.wing.offset(2)) 'px offset'];
            case winge1adjust
                state.track.wing.extent(1) = w.Value;
                if state.track.wing.lock 
                    state.track.wing.extent(2) = w.Value;
                    winge2adjust.Value = w.Value;
                    winge2setdisplay.String = [num2str(state.track.wing.extent(2)) 'px extent'];
                end
                winge1setdisplay.String = [num2str(state.track.wing.extent(1)) 'px extent'];
            case winge2adjust
                state.track.wing.extent(2) = w.Value;
                winge2setdisplay.String = [num2str(state.track.wing.extent(2)) 'px extent'];
            case wingn1adjust
                n=w.Value;
                wingn1setdisplay.String = [num2str(n) 'px tracked'];
                if state.track.wing.lock 
                    state.track.wing.npts(2) = n;
                    wingn2adjust.Value = n;
                    wingn2setdisplay.String = [num2str(n) 'px tracked'];
                end
                state.track.wing.npts(1) = n;
            case wingn2adjust
                n=w.Value;
                state.track.wing.npts(2) = n;
                wingn2setdisplay.String = [num2str(n) 'px tracked'];
            case wingl1adjust
                l=w.Value;
                wingl1setdisplay.String = [num2str(360-l) '° lower'];
                state.track.wing.ltheta(1) = l;
                if state.track.wing.lock
                    u = wrapTo360(180+(360-l));
                    wingu2setdisplay.String = [num2str(360-u) '° upper'];
                    wingu2adjust.Value = u;
                end
            case wingl2adjust
                l=w.Value;
                state.track.wing.ltheta(2) = l;
                wingl2setdisplay.String = [num2str(360-l) '° lower'];
            case wingu1adjust
                u=w.Value;
                wingu1setdisplay.String = [num2str(360-u) '° upper'];
                state.track.wing.utheta(1) = u;
                if state.track.wing.lock
                    l = wrapTo360(180+(360-u));
                    state.track.wing.ltheta(2) = l;
                    wingl2setdisplay.String = [num2str(360-l) '° lower'];
                end
            case wingu2adjust
                u=w.Value;
                wingu2setdisplay.String = [num2str(360-u) '° upper'];
                state.track.wing.utheta(2) = u;
        end
        
        if boundschanged
            % check if bounds have reversed
            if wingu1adjust.Value<=wingl1adjust.Value
                state.track.wing.utheta(1) = wingu1adjust.Value+360;
            else
                state.track.wing.utheta(1) = wingu1adjust.Value;
            end
            if wingu2adjust.Value<=wingl2adjust.Value
                state.track.wing.utheta(2) = wingu2adjust.Value+360;
            else
                state.track.wing.utheta(2) = wingu2adjust.Value;
            end
        end
    
        updatetracking;
    end
    function makewingmask()
        wr = double(state.track.wing.root);
        r1 = state.track.wing.offset;
        r2 = state.track.wing.offset+state.track.wing.extent;
        lt = state.track.wing.ltheta+state.track.orientation;
        rt = state.track.wing.utheta+state.track.orientation;
        w = state.vid.width;
        h = state.vid.height;
        [mask1, poly1] = make_arc_mask(wr(1),wr(3),r1(1),r2(1),lt(1),rt(1),w,h);
        [mask2, poly2] = make_arc_mask(wr(2),wr(4),r1(2),r2(2),lt(2),rt(2),w,h);
        state.track.wing.mask = logical(zeros(h,w,2));
        state.track.wing.mask(:,:,1) = mask1;
        state.track.wing.mask(:,:,2) = mask2;
        state.track.wing.poly = [poly1;poly2];
    end
%% head tracking ui functions
    function updateheadtracking(h,~)
        
%         if  any([headladjust,headuadjust]==h)
%             boundschanged = true;
%             
%             if h.Value == -1
%                 h.Value = 359;
%             elseif h.Value == 360
%                 h.Value = 0;
%             end
%         else
%             boundschanged = false;
%         end
        
        switch h
            case headmethoddropdown
                state.track.head.method = h.Value;
            case headnormdropdown
                state.track.head.norm = h.Value;
            case overlayheadcheck
                state.track.head.show.thresh = h.Value;
            case headtadjust
                t=h.Value;
                headtsetdisplay.String = [num2str(t*100) '% thresh'];
                state.track.head.thresh = t;
            case headoadjust
                o=h.Value;
                headosetdisplay.String = [num2str(o) 'px offset'];
                state.track.head.offset = o;
            case headeadjust
                e=h.Value;
                headesetdisplay.String = [num2str(e) 'px extent'];
                state.track.head.extent = e;
            case headnadjust
                n=h.Value;
                headnsetdisplay.String = [num2str(n) 'px tracked'];
                state.track.head.npts = n;
            case headladjust
                l=h.Value;
                headlsetdisplay.String = [num2str(360-l) '° lower'];
                state.track.head.ltheta = l;
            case headuadjust
                u=h.Value;
                headusetdisplay.String = [num2str(360-u) '° upper'];
                state.track.head.utheta = u;
        end
%         if boundschanged
%             % check if bounds have reversed
%             if headuadjust.Value<=headladjust.Value
%                 state.track.head.utheta = headladjust.Value+360;
%             else
%                 state.track.head.utheta = headladjust.Value;
%             end
%         end
        updatetracking();
    end
    function makeheadmask()
        hr = double(state.track.head.root);
        r1 = state.track.head.offset;
        r2 = state.track.head.offset+state.track.head.extent;
        lt = state.track.head.ltheta+state.track.orientation;
        rt = state.track.head.utheta+state.track.orientation;
        w = state.vid.width;
        h = state.vid.height;
        [mask, poly] = make_arc_mask(hr(1),hr(2),r1,r2,lt,rt,w,h);
        state.track.head.mask = mask;
        state.track.head.poly = poly;
    end
%% abdomen tracking ui functions    
    function updateabdtracking(a,~)
        
%         if  any([abdladjust,abduadjust]==a)
%             boundschanged = true;
%             
%             if a.Value == -1
%                 a.Value = 359;
%             elseif h.Value == 360
%                 a.Value = 0;
%             end
%         else
%             boundschanged = false;
%         end
        
        switch a
            case abdnormdropdown
                state.track.abd.norm = a.Value;
            case overlayabdcheck
                state.track.abd.show.thresh = a.Value;
            case abdtadjust
                t=a.Value;
                abdtsetdisplay.String = [num2str(t*100) '% thresh'];
                state.track.abd.thresh = t;
            case abdoadjust
                o=a.Value;
                abdosetdisplay.String = [num2str(o) 'px offset'];
                state.track.abd.offset = o;
            case abdeadjust
                e=a.Value;
                abdesetdisplay.String = [num2str(e) 'px extent'];
                state.track.abd.extent = e;
            case abdnadjust
                n=a.Value;
                abdnsetdisplay.String = [num2str(n) 'px tracked'];
                state.track.abd.npts = n;
            case abdladjust
                l=a.Value;
                abdlsetdisplay.String = [num2str(360-l) '° lower'];
                state.track.abd.ltheta = l;
            case abduadjust
                u=a.Value;
                abdusetdisplay.String = [num2str(360-u) '° upper'];
                state.track.abd.utheta = u;
        end
        
%         if boundschanged
%             % check if bounds have reversed
%             if abduadjust.Value<=abdladjust.Value
%                 state.track.abd.utheta = abdladjust.Value+360;
%             else
%                 state.track.abd.utheta = abdladjust.Value;
%             end
%         end
        
        updatetracking();
    end
    function makeabdmask()
        ar = double(state.track.abd.root);
        r1 = state.track.abd.offset;
        r2 = state.track.abd.offset+state.track.abd.extent;
        lt = state.track.abd.ltheta+state.track.orientation;
        rt = state.track.abd.utheta+state.track.orientation;
        w = state.vid.width;
        h = state.vid.height;
        [mask, poly] = make_arc_mask(ar(1),ar(2),r1,r2,lt,rt,w,h);
        state.track.abd.mask = mask;
        state.track.abd.poly = poly;
    end
%% plotting functions
    function plotdata()
        if ~state.showdata;return;end
        data = [];
        titles = {};
        pcolors = {};
        di = 0;
        if plotheadcheck.Value && (trackheadcheck.Value && ~isempty(state.track.head.angle))
            di = di+1;
            data = [data; state.track.head.angle];
            titles{di} = 'Head';
            pcolors{di} = colors.head./255;
        end
        if plotwingcheck.Value && (trackwingcheck.Value && ~isempty(state.track.wing.angle))
            di = di+1;
            data = [data; state.track.wing.angle(1,:)];
            titles{di} = 'Left Wing';
            pcolors{di} = colors.wing./255;
            
            di = di+1;
            data = [data; state.track.wing.angle(2,:)];
            titles{di} = 'Right Wing';
            pcolors{di} = colors.wing./255;
        end
        if plotabdcheck.Value && (trackabdcheck.Value && ~isempty(state.track.abd.angle))
            di = di+1;
            data = [data; state.track.abd.angle];
            titles{di} = 'Abdomen';
            pcolors{di} = colors.abd./255;
        end
        
        if di==0
            return;
        elseif ~isvalid(tf)
            tf = figure('Name','Kinematic Trace','NumberTitle','off',...
            'MenuBar','none','Resize','off','Position',[800 175 500 500]);
            datax = axes(tf);
        end
        
        if strcmp(tf.Visible,'off');tf.Visible = 'on';end
        t = state.track.ts;
        lines = plot(datax,t,data);hold(datax,'on')
        [lines.Color] = deal(pcolors{:});
        [lines.ButtonDownFcn] = deal(@playctrl);
        x = state.vid.ix/state.vid.fps;
        plot(datax,[x x],[0 360],'Color','Black');hold(datax,'off')
        datax.HitTest = 'on';
        datax.ButtonDownFcn = @playctrl;
        ylim(datax,[0 360])
        yticks(datax,0:30:360);
        xlim(datax,[0 state.vid.nframes/state.vid.fps]);
        hold(datax,'off')
        box(datax,'off');
        xlabel(datax,'Time (s)');
        ylabel(datax,'Angle (°)');
    end
%% utility functions
    function updatetracking()
        if ~isempty(state.track.head.root)
            hr = state.track.head.root;
            headrootxadjust.Enable = 'on';
            headrootxadjust.Value = hr(1);
            headrootyadjust.Enable = 'on';
            headrootyadjust.Value = state.vid.height-hr(2);
            headsetdisplay.String = ['x=' num2str(hr(1)) ' y=' num2str(hr(2))];            
        end
        if ~isempty(state.track.abd.root)
            ar = state.track.abd.root;
            abdrootxadjust.Enable = 'on';
            abdrootxadjust.Value = ar(1);
            abdrootyadjust.Enable = 'on';
            abdrootyadjust.Value = state.vid.height-ar(2);
            abdsetdisplay.String = ['x=' num2str(ar(1)) ' y=' num2str(ar(2))];            
        end
        if ~isempty(state.track.abd.root) && ~isempty(state.track.head.root)
            trackpanel.Visible = 'on';
            if ~isempty(findobj('Parent',tabs))
                tabs.Visible = 'on';
            else
                tabs.Visible = 'off';
            end           
            calcbodyaxiswingroots;
            makewingmask;
            makeheadmask;
            makeabdmask;
        end
        
        if strcmp(state.vid.vtimer.Running,'off')
            processframe();
            showframe();
            plotdata();
        end
    end

    function calcbodyaxiswingroots()
        ar = double(state.track.abd.root);
        hr = double(state.track.head.root);
        state.track.orientation = atan2d(ar(2)-hr(2),ar(1)-hr(1))-90;
        d = pdist2(hr,ar,'euclidean');  
        state.track.wing.ap(1) = round(wingap1adjust.Value*d*.01);
        state.track.wing.ml(1) = round(wingml1adjust.Value*d*.01);
        state.track.wing.ap(2) = round(wingap2adjust.Value*d*.01);
        state.track.wing.ml(2) = round(wingml2adjust.Value*d*.01);
        ap = state.track.wing.ap;
        ml = state.track.wing.ml;
        wc(1) = ar(1)+(ap(1))*sind(state.track.orientation);
        wc(2) = ar(2)-(ap(1))*cosd(state.track.orientation);
        wr(1,1) = wc(1)+(ml(1))*sind(state.track.orientation-90);
        wr(1,2) = wc(2)-(ml(1))*cosd(state.track.orientation-90);
        
        wc(1) = ar(1)+(ap(2))*sind(state.track.orientation);
        wc(2) = ar(2)-(ap(2))*cosd(state.track.orientation);
        wr(2,1) = wc(1)+(ml(2))*sind(state.track.orientation+90);
        wr(2,2) = wc(2)-(ml(2))*cosd(state.track.orientation+90);
        state.track.wing.root = wr; 
    end

    function [angle, pts, bw] = trackborder(img,mask,root,thresh,norm,npts,side)
        if sum(sum((mask)))==0
            angle = nan;
            pts = nan;
            bw = nan;
            return
        end
        if nargin<7
            side = 'lower';
        end
        root = double(root);
        img = rgb2gray(img);
       if norm == 2 % normalize tracking ROI only
            img = imadjust(img,stretchlim(img(mask)));
       elseif norm == 3 %normalize whole image
           img = imadjust(img);
       end
        bw  = imbinarize(img,thresh)&mask;
        p = regionprops(bw,'Area','PixelList');     
        
        if  isempty(p) | bw == mask
            angle = nan; %null tracking if the ROI is whited out
            pts = nan;
        elseif ~any(bw(:)~=0) || npts <=1
            angle = nan; %null tracking if the ROI is blacked out
            pts = nan;        
        else
            [~, ix] = max([p.Area]);
            x = p(ix).PixelList(:,1);
            y = p(ix).PixelList(:,2);
            
            [theta, rho] = cart2pol(x-root(1),y-root(2));
            theta = rad2deg(theta);
            theta(theta<-90)=360+theta(theta<-90);
            switch side
                case 'lower'
                    [~,tix] = sort(theta,'descend');
                case 'upper'
                    [~,tix] = sort(theta,'ascend');
            end
            if length(rho)<npts
                npts = length(rho);
            end
            tix = tix(1:npts);
            theta = theta(tix);
            x = x(tix);
            rho = rho(tix);
            y = y(tix);
            if isempty(rho)
                angle = NaN;
                pts = NaN;
            else
                pts = [x, y];
                angle = mean(theta);
            end
        end
    end
    function [angle, pts,bw] = tracktip(img,mask,root,thresh,norm,npts,mode,arg)
        if nargin<7
            mode = 1;
        end
        if nargin<8
            switch mode
                case 1 % average of distribution tails
                    arg = [10 90]; %upper and lower 10 percentiles default
                case 2 % average of k-means cluster centroids
                    arg = 2; %2 clusters default
            end
        end
        root = double(root);
        img = rgb2gray(img);
       if norm == 2 % normalize tracking ROI only
            img = imadjust(img,stretchlim(img(mask)));
       elseif norm == 3 %normalize whole image
           img = imadjust(img);
       end
        bw  = imbinarize(img(:,:,1),thresh)&mask;
        p = regionprops(bw,'Area','PixelList');     
        
        if  isempty(p) | bw == mask
            angle = nan; %null tracking if the ROI is whited out
            pts = nan;
        elseif ~any(bw(:)~=0) || npts <=1
            angle = nan; %null tracking if the ROI is blacked out
            pts = nan;
        else
            [~, ix] = max([p.Area]);
            x = p(ix).PixelList(:,1);
            y = p(ix).PixelList(:,2);           
            
            [theta, rho] = cart2pol(x-root(1),y-root(2));
            theta = rad2deg(theta);
            [~,rix] = sort(rho,'descend');
            if length(rho)<npts
                npts = length(rho);
            end
            rix = rix(1:npts);
            theta = theta(rix);
            rho = rho(rix);
            x = x(rix);
            y = y(rix);
            switch mode
                case 1 % distribution tails
                    angle = median([prctile(theta,arg(1)),prctile(theta,arg(2))]);
                    pts = [x, y];
                case 2 % k-means
                    if arg == 1 %no clustering to do if there's only 1
                        pts = [x, y];
                        angle = mean(theta);
                    else
                        try
                            k = kmeans([theta rho],arg,'Distance','cosine');
                            m = [];
                            for i = 1:arg
                                m = [m mean(theta(k==i))];
                            end
                            pts = [x, y];
                            angle = mean(m);
                        catch err
                            pts = NaN;
                            angle = NaN;
                        end
                    end
            end
        end
    end
    function [mask, poly] = make_arc_mask(centx,centy,r1,r2,theta1,theta2,w,h)
        angle = linspace(theta1,theta2);
        
        x1 = r1*cosd(angle);
        x2 = r2*cosd(angle);
        
        y1 = r1*sind(angle);
        y2 = r2*sind(angle);
        
        %make intervening points between two arcs for the end caps
        x3 = (x1(1) + x2(1))/2;
        y3 = (y1(1) + y2(1))/2;
        
        x4 = (x1(end) + x2(end))/2;
        y4 = (y1(end) + y2(end))/2;
        
        xvals = [flip(x1) x3 x2 x4];
        yvals = [flip(y1) y3 y2 y4];
        
        xvals = xvals+centx;
        yvals = yvals+centy;
        mask = poly2mask(xvals,yvals,h,w);
        
        %poly2mask wants the polygon as two vectors of x and y points but
        %insertshape wants it as one vector of sequential x and y pairs so
        %we'll output the poly in a form friendly for that.
        poly = [xvals(:)';yvals(:)']; %define as rows, pair as two columns
        poly = poly(:)'; %flatten then flip back to one row.
    end
    function pt = pickpt(n)
        if nargin<1
            n = 1;
        end
        axes(state.vid.ax);
        h = get(0,'ScreenSize');
        h = h(4);
        mouse.mouseMove(vf.Position(1)+vf.Position(3)/2,...
            h-(vf.Position(2)+vf.Position(4)/2));
        pt = int16(ginput(n));
        pt = double(pt);
    end
    function rgb = overlaythresh(rgb,color,bw)        
        rgb = imoverlay(rgb,bw,color./255);
    end
end