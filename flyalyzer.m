% Flyalyzer, Michael Rauscher 2019

function flyalyzer(vidname)
    %only allow one running instance
    fgs=findobj('Type','figure');
    if ~isempty(fgs)
        if any(contains({fgs.Name},'Flyalyzer'));return;end
    end

%% state variable declaration
    import java.awt.Robot;
    mouse = Robot; %for moving mouse over the image frame to pick points
    closing = false;
    colors = getcolors(1);
    
    vreader = []; %will be assigned the VideoReader object for active file
    vtimer = timer; %timer for playing the video
    vtimer.Period = .001;
    vtimer.TimerFcn = @nextframe;
    vtimer.ExecutionMode = 'fixedSpacing';
    vtimer.BusyMode = 'queue';
    
    %UIControl state variables that survive loading and saving a file
    state = initializestatevariables();
%% ui figure init
    cf = figure('Name','Flyalyzer','NumberTitle','off',...
    'MenuBar','none','Resize','off','Position',[50 175 250 500],...
    'CloseRequestFcn',@closecleanup);

    vf = figure('Name','','NumberTitle','off','Visible','off',...
    'MenuBar','none','Resize','on','Position',[300 175 500 666],...
    'CloseRequestFcn',@closecleanup);
    vidax = axes(vf);
    im = [];
    
    tf = figure('Name','Kinematic Trace','NumberTitle','off','Visible','off',...
    'MenuBar','none','Resize','off','Position',[966 175 500 500],...
    'CloseRequestFcn',@closecleanup);
    datax = axes(tf);
    lines = line(datax);    
    ui = initializeuicontrols();
        
%% input argument handling
if nargin>0
    [vidfilepath,vidfilename,ext]=fileparts(vidname);
    if isempty(vidfilepath);vidfilepath = pwd;end
    if exist(vidname,'file') == 2
        loadvid([vidfilename ext],vidfilepath);
    end
end
%% main support functions
    function nextframe(~,~)
        if (state.vid.ix+1)>state.vid.nframes
            if state.vid.loop
                setframeix(1);
            else
                stop(vtimer);
                ui.playpause.String = '>';
            end
        else
            setframeix(state.vid.ix+1);
        end
    end
    function setframeix(ix)
        if verLessThan('MATLAB','9.7')
            %if the requested frame is the next frame we can just read the next
            %frame, so we'll only set the video time if we need to
            if ix~=(state.vid.ix+1)
                vreader.CurrentTime = state.vid.timeix(ix);
            end
            state.vid.curframe = readFrame(vreader);
        else
            state.vid.curframe = read(vreader,ix);
        end
        state.vid.ix = ix;
%         if state.vid.timeix(min([ix+1 state.vid.nframes]))~=vreader.CurrentTime
%             t1 = state.vid.timeix(min([ix+1 state.vid.nframes]))
%             t2= vreader.CurrentTime
%         end
        ui.progress.Value = ix;
        ui.dispframe.String = ['Frame ' num2str(ix) ' of ' num2str(state.vid.nframes)];
        processframe();
        showframe();
        plotdata();
    end
    function processframe()
        img = state.vid.curframe;
        if state.vid.invertbw;img = imcomplement(img);end        
        out = img;
        if ~isempty(state.track.abd.root) && ~isempty(state.track.head.root)      
            wing = state.track.wing;
            head = state.track.head;
            abd = state.track.abd;
            leg = state.track.leg;
            
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
            if ui.trackwingcheck.Value && ~isempty(state.track.wing.poly)
                [angle1,pts1,bw1] = trackborder(img,wing.mask(:,:,1),wing.root(1,:),wing.thresh(1),wing.norm,wing.npts(1),'lower');
                angle1 = wrapTo360(angle1);
                r = wing.extent(1)+wing.offset(1);
                pt2(1) = wing.root(1,1)+r*cosd(angle1);
                pt2(2) = wing.root(1,2)+r*sind(angle1);
                wlineL = [wing.root(1,:) pt2];
                [angle2,pts2,bw2] = trackborder(img,wing.mask(:,:,2),wing.root(2,:),wing.thresh(2),wing.norm,wing.npts(2),'upper');
                angle2 = wrapTo360(angle2);
                r = wing.extent(2)+wing.offset(2);
                pt2(1) = wing.root(2,1)+r*cosd(angle2);
                pt2(2) = wing.root(2,2)+r*sind(angle2);
                wlineR = [wing.root(2,:) pt2];           
                
                %record values (switch from y-inverted computer graphics
                %coordinates to conventional coordinates)
                state.track.wing.angle(1:2,state.vid.ix) = [360-angle1;360-angle2];
                
                % draw thresh
                if wing.show.thresh
                    out = overlaythresh(out,colors.wingL./2,bw1);
                    out = overlaythresh(out,colors.wingR./2,bw2);
                end
                
                if ~any(isnan([wlineL wlineR]))
                    out = insertShape(out,'Line',wlineL,'color',colors.wingL);
                    out = insertShape(out,'Line',wlineR,'color',colors.wingR);

                    if wing.show.pts
                        out = insertMarker(out,pts1,'+','color',colors.wingL);
                        out = insertMarker(out,pts2,'+','color',colors.wingR);
                    end
                end
                if wing.show.poly
                    out = insertShape(out,'Polygon',wing.poly(1,:),'color',colors.wingL);
                    out = insertShape(out,'Polygon',wing.poly(2,:),'color',colors.wingR);
                end
            end
            
            if ui.trackheadcheck.Value && ~isempty(state.track.head.poly)
                
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
            if ui.trackabdcheck.Value && ~isempty(state.track.abd.poly)                
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
        
        if ui.tracklegcheck.Value && ~isempty(state.track.leg.poly)
            [angle,tip,extrema,bw] = tracklegs(img,leg.mask,leg.borderidx,leg.root,leg.threshint,leg.threshsize,ui.legnormdropdown.Value);

            if leg.show.thresh
                out = overlaythresh(out,colors.leg./2,bw);
            end
            if ~all(isnan(extrema))
                if ~any(isnan(extrema(1,:)))
                    out = insertShape(out,'Polygon',extrema(1,:),'color',255-colors.leg);
                    if leg.show.pts
                        out = insertMarker(out,tip(1,:),'+','color',colors.leg);
                    end
                end
                if ~any(isnan(extrema(2,:)))
                    out = insertShape(out,'Polygon',extrema(2,:),'color',255-colors.leg);
                    if leg.show.pts
                        out = insertMarker(out,tip(2,:),'+','color',colors.leg);
                    end
                end         
            end
            % record leg orientations
            state.track.leg.angle(1:2,state.vid.ix) = 360-angle;
            % now that we're done drawing correct for y-inverted computer
            % graphics coordinates before saving data;
            tip(:,2)=size(leg.mask,1)-tip(:,2);
            state.track.leg.tip(1:2,state.vid.ix)=tip(1,:);
            state.track.leg.tip(3:4,state.vid.ix)=tip(2,:);
            
            if leg.show.poly
                out = insertShape(out,'Polygon',state.track.leg.poly,'color',colors.leg);
            end
        end
        
        if ~isempty(state.track.head.root)
            out = insertMarker(out,state.track.head.root,'s','color',colors.head);            
        end
        if ~isempty(state.track.abd.root)
            out = insertMarker(out,state.track.abd.root,'s','color',colors.abd);
        end
        if ~isempty(state.track.wing.root) && ui.trackwingcheck.Value
            out = insertMarker(out,state.track.wing.root(1,:),'s','color',colors.wingL);
            out = insertMarker(out,state.track.wing.root(2,:),'s','color',colors.wingR);
        end
        if ~isempty(state.track.leg.root) && ui.tracklegcheck.Value
            legline = [state.track.leg.root(1,:) state.track.leg.root(2,:)];
            out = insertShape(out,'Line',legline,'color',colors.leg);
        end
        
        state.vid.dispframe = out;
    end    
    function showframe()
%         imagesc(vidax,state.vid.dispframe);
        im.CData = state.vid.dispframe;
%         hold on
%         if ~isempty(state.track.leg.poly) && state.track.leg.show.poly
%             polyx = state.track.leg.poly(1:2:end);
%             polyy = state.track.leg.poly(2:2:end);
%             polyx(end+1) = polyx(1);
%             polyy(end+1) = polyy(1);
%             plot(vidax,polyx,polyy,'Color',colors.leg./255);
%             hold off
%         end
        set(vidax,'TickLength',[0 0]);
    end
%% program and play control functions
    function closecleanup(h,~)
        if h==tf && ~closing
            %don't actually close the plot window unless we're actually
            %closing the program
            tf.Visible = 'off';
            ui.plotwingcheck.Value = false;
            ui.plotheadcheck.Value = false;
            ui.plotabdcheck.Value = false;
            ui.plotlegcheck.Value = false;
            updateacquisition(ui.plotwingcheck,[]);
            updateacquisition(ui.plotheadcheck,[]);
            updateacquisition(ui.plotabdcheck,[]);
            updateacquisition(ui.plotabdcheck,[]);
            return
        else
            %which we do by setting this flag and then asking for the close
            %function again
            closing = true;
            closereq
        end
        %stop the timer in case the video is playing
        stop(vtimer);
        drawnow;%clear the java event stack to force wait for timer stop
        delete(vreader);
        try delete(cf);catch;end
        try delete(vf);catch;end
        try delete(tf);catch;end
    end
    function savedata(b,~)
        fly = buildoutputstruct();
        switch b
            case ui.exportbutton
                badvarname = true;
                while badvarname %loop til we get a cancellation or acceptable variable name
                    varname = inputdlg('Enter name for workspace variable:','',[1 35],{'fly'});
                    if isempty(varname);return;end %cancel button
                    varname = varname{1};
                    badvarname = ~strcmp(varname,genvarname(varname));
                end
                basevars = evalin('base','who');
                if any(contains(basevars,varname))
                    over=questdlg('Overwrite existing workspace variable?','','Yes','No','No');
                    if strcmp(over,'No');return;end
                end
                assignin('base',varname,fly);
            case ui.savebutton
                savefilename = [fullfile(state.vid.path,state.vid.basename) '_PROC'];
%                 savefilename = [savefilename '_flyalyzer' datestr(now,'_yyyymm_hhMMSS_PROC')];
                uisave('fly',savefilename)
        end
    end
    function fly = buildoutputstruct()
        fly = struct;
        if isfield(state.track,'orientation')
            %use body orientation to transform kinematics into body-centric
            %coordinates rather than image-centric coordinates
            bodycorrect = state.track.orientation;
        end
        if ui.trackheadcheck.Value
            state.track.head.check = true;
            fly.head.angle = wrapTo360(state.track.head.angle+bodycorrect);
            fly.head.root = state.track.head.root;
        else
            state.track.head.check = false;
        end
        state.track.head.show.check = ui.plotheadcheck.Value;
        
        if ui.trackwingcheck.Value
            state.track.wing.check = true;
            fly.wingL.angle=wrapTo360(state.track.wing.angle(1,:)+bodycorrect);
            fly.wingL.root = state.track.wing.root(1,:);
            fly.wingR.angle=wrapTo360(state.track.wing.angle(2,:)+bodycorrect);
            fly.wingR.root = state.track.wing.root(2,:);
        else
            state.track.wing.check = false;
        end
        state.track.wing.show.check = ui.plotwingcheck.Value;

        if ui.trackabdcheck.Value
            state.track.abd.check = true;
            fly.abd.angle = wrapTo360(state.track.abd.angle+bodycorrect);
            fly.abd.root = state.track.abd.root;
        else
            state.track.abd.check = false;
        end
        state.track.abd.show.check = ui.plotabdcheck.Value;
        
        if ui.tracklegcheck.Value
            state.track.leg.check = true;
            fly.legL.angle = wrapTo360(state.track.leg.angle(1,:)+bodycorrect);
            fly.legL.tipX = state.track.leg.tip(1,:);
            fly.legL.tipY = state.track.leg.tip(2,:);
            fly.legR.angle = wrapTo360(state.track.leg.angle(2,:)+bodycorrect);
            fly.legR.tipX = state.track.leg.tip(3,:);
            fly.legR.tipY = state.track.leg.tip(4,:);
        else
            state.track.leg.check = false;
        end
        state.track.leg.show.check = ui.plotlegcheck.Value;
        
        fly.timestamps = state.track.ts;
        fly.numframes = state.vid.nframes;
        fly.duration = state.vid.nframes/state.vid.fps;
        fly.fps = state.vid.fps;
        fly.imageH = vreader.Height;
        fly.imageW = vreader.Width;
        fly.filename = [state.vid.basename state.vid.ext];
        fly.uisettings = state;
    end
    function loadbtn(~,~)
        [fname,pname,fix] = uigetfile({'*.avi;*.mp4;*.mat',...
            'Video and Data Files (*.avi, *.mp4, *.mat)';
            '*.avi;*.mp4',...
            'Videos (*.avi, *.mp4)';
            '*.mat',...
            'MATLAB Data (*.mat)'},...
            'Select Video or Data file',state.vid.path);
%         [fname,pname,fix] = uigetfile({'*.avi;*.mp4'},'Select Video or Data file',state.vid.path);
        if fix == 0;return;end
        loadvid(fname,pname);
    end

    %load video function. this is a mess right now but it works
    function loadvid(fname,pname)        
        if strcmp(vtimer.Running,'on')
            stop(vtimer);
            ui.playpause.String = '>';
        end
        
        state.vid.path = pname;
        [~,basename,fileext] = fileparts(fname);
        if strcmp(fileext,'.mat')
            fly = struct;
            err = false;
            try
                load(fullfile(pname,fname));
            catch
                err = true;
            end
            if err || ~isfield(fly,'uisettings')
                msgbox('This is not a useable data file','Invalid Data File','Error');
                return
            end
            vidfname = [fullfile(fly.uisettings.vid.path,fly.uisettings.vid.basename) fly.uisettings.vid.ext];
            %try data file directory if video not found (say if we're on a
            %different computer and the path is different now);
            if exist(vidfname,'file')~=2
                vidfname = [fullfile(pname,fly.uisettings.vid.basename) fly.uisettings.vid.ext];
                if exist(vidfname,'file')~=2
                    qst = questdlg('The video file listed in this data file was not found. Select manually?','Video File Not Found','Yes','No','Yes');
                    switch qst
                        case 'Yes'
                            [nfname,npname,ffix] = uigetfile({'*.avi;*.mp4'}, ['Select Video matching ' fly.uisettings.vid.basename],state.vid.path);
                            if ffix == 0;return;end
                            vidfname = fullfile(npname,nfname);
                            [fly.uisettings.vid.path,...
                                fly.uisettings.vid.basename,...
                                fly.uisettings.vid.ext] = fileparts(vidfname);
                        case 'No'
                            return
                    end
                end
            end
            
            state = fly.uisettings;
            restoreuicontrols;
            vreader = VideoReader(vidfname);
            set(ui.loadbutton,'Position',[3 432 60 65]);
            pos = vf.Position;
            pos(4) = 500;
            pos(3) = 500*state.vid.width/state.vid.height;
            vf.Name = state.vid.basename;
            vf.Position = pos;
            vf.Visible = 'on';
            vidax.Position = [0 0 1 1];
            setframeix(state.vid.ix);
            im = imagesc(vidax,state.vid.dispframe);
            updatetracking();
            return
        end
        
        vr = VideoReader(fullfile(pname,fname));
        state.vid.basename= basename;
        state.vid.ext = fileext;
        
        if verLessThan('MATLAB','9.7')
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
        else
            
            numframes = vr.NumFrames;
            timeix = ((0:numframes-1)./vr.FrameRate)+vr.CurrentTime;
        end
        
        ui.progress.Value = 1;
        ui.progress.Max = numframes;
        ui.progress.SliderStep = [1/(numframes-1) 1/(numframes-1)];
        
        vreader = vr;
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
        set(ui.fpsdisplay,'String',[num2str(state.vid.fps) 'FPS']);
        pos = vf.Position;
        pos(4) = 500;
        pos(3) = 500*state.vid.width/state.vid.height;
        vf.Name = state.vid.basename;
        vf.Position = pos;
        vf.Visible = 'on';
        im = imagesc(vidax,state.vid.dispframe);
        vidax.Position = [0 0 1 1];
        vidax.XTick = [];
        vidax.YTick = [];
        if ~verLessThan('Matlab','9.5')
            tb = axtoolbar(vidax,'default');
        end
        tb.Visible = 'off';
        ui.trackwingcheck.Value = false;
        ui.trackheadcheck.Value = false;
        ui.trackabdcheck.Value = false;
        ui.tracklegcheck.Value = false;
        updateacquisition(ui.trackwingcheck,[]);
        updateacquisition(ui.trackheadcheck,[]);
        updateacquisition(ui.trackabdcheck,[]);
        updateacquisition(ui.tracklegcheck,[]);
        updatewingtracking(ui.lockwingscheck,[]);
        
        ui.vidpanel.Visible = 'on';
        ui.setuppanel.Visible = 'on';
        set(ui.loadbutton,'Position',[3 432 60 65]);
        set(ui.headrootxadjust,'Min',0,'Max',state.vid.width,'Value',0,...
            'SliderStep',[1/state.vid.width 10/state.vid.width],'Enable','off');
        set(ui.headrootyadjust,'Min',0,'Max',state.vid.height,'Value',0,...
            'SliderStep',[1/state.vid.width 10/state.vid.height],'Enable','off');
        set(ui.abdrootxadjust,'Min',0,'Max',state.vid.width,'Value',0,...
            'SliderStep',[1/state.vid.width 10/state.vid.width],'Enable','off');
        set(ui.abdrootyadjust,'Min',0,'Max',state.vid.height,'Value',0,...
            'SliderStep',[1/state.vid.width 10/state.vid.height],'Enable','off');
        ui.headsetdisplay.String = '';
        ui.abdsetdisplay.String = '';
        
        state.track.wing.angle = nan(2,numframes);
        state.track.head.angle = nan(1,numframes);
        state.track.abd.angle = nan(1,numframes);
        state.track.leg.angle = nan(2,numframes);
        state.track.leg.tip = nan(4,numframes);
        state.track.ts = linspace(0,numframes/fps,numframes);
       
        keepbody = false;
        if ~isempty(state.track.head.root) && ~isempty(state.track.abd.root)
            response = questdlg('Keep Body Axis Definiton Points?','Keep Body Points','Yes','No','No');
            keepbody = strcmp(response,'Yes');
        end
        
        if ~keepbody
            state.track.head.root = [];
            state.track.head.mask = [];
            state.track.head.poly = [];
            state.track.abd.root = [];
            state.track.abd.mask = [];
            state.track.abd.poly = [];
        end
        
        state.track.wing.root = [];
        state.track.wing.mask = [];
        state.track.wing.poly = [];
        state.track.leg.root = [];
        state.track.leg.mask = [];
        state.track.leg.poly = [];
        
        state.showdata = false;
        
        ui.trackpanel.Visible = 'off';
        updatewingtracking(ui.lockwingscheck,[]);
        
        if strcmp(tf.Visible,'on');tf.Visible = 'off';end
        setframeix(1);
    end
    function playctrl(h,e)
        switch h
            case ui.dispframe
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
            case ui.stopbutton
                stop(vtimer)
                setframeix(1);
            case ui.playpause
                if strcmp(vtimer.Running,'off')
                    if ui.progress.Value == ui.progress.Max && ~state.vid.loop
                        setframeix(1);
                    else
                        start(vtimer);                                            
                    end
                else
                    stop(vtimer);
                end
            case ui.progress
                setframeix(round(ui.progress.Value));
            case {datax,lines}
                if ~strcmp(e.EventName,'Hit');return;end
                ix=e.IntersectionPoint(1);
                if strcmp(ui.ixtbtn.String,'t')
                    ix = floor(ix);
                else
                    ix = floor(ix*state.vid.fps);                  
                end                
                if ix<1;ix = 1;end
                if ix>state.vid.nframes;ix = state.vid.nframes;end
                setframeix(ix);
            case ui.loopcheck
                state.vid.loop = h.Value;
        end
        if strcmp(vtimer.Running,'on')
            ui.playpause.String = '||';
        else
            ui.playpause.String = '>';    
        end
    end
%% acquisition control functions
    function updateacquisition(a,~)
       c = {ui.trackwingcheck,ui.trackheadcheck,ui.trackabdcheck,ui.tracklegcheck};
       p = {ui.plotwingcheck,ui.plotheadcheck,ui.plotabdcheck,ui.plotlegcheck};       
       t = {ui.wingtab,ui.headtab,ui.abdtab,ui.legtab};
       tabchanged = false;
       switch a
           case c
               tabchanged = true;
               ix = find([c{:}]==a);
               %turn plotting on with tracking by default
               if a.Value == true
                p{ix}.Value = a.Value;
                updateacquisition(p{ix},[]);
               end
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
           case ui.invertcheck
               state.vid.invertbw = a.Value;
           case ui.headptbutton
               state.track.head.root=pickpt(1);
           case ui.headrootxadjust
               hr = state.track.head.root;
               hr(1) = int16(a.Value);
               state.track.head.root = hr;
           case ui.headrootyadjust
               hr = state.track.head.root;
               hr(2) = int16(state.vid.height-a.Value);
               state.track.head.root = hr;
           case ui.abdrootxadjust
               ar = state.track.abd.root;
               ar(1) = int16(a.Value);
               state.track.abd.root = ar;
           case ui.abdrootyadjust
               ar = state.track.abd.root;
               ar(2) = int16(state.vid.height-a.Value);
               state.track.abd.root = ar;
           case ui.abdptbutton
               state.track.abd.root=pickpt(1); 
           case ui.clearheadbutton
              opt = questdlg('Clear Head Data?','Clear Head Data','This Frame','Range','All','This Frame');
              if isempty(opt);return;end
              newdata = state.track.head.angle;
              switch opt
                  case 'This Frame'
                      newdata(state.vid.ix) = nan;
                  case 'Range'
                      ropt = questdlg('Clear Head Data Range?','Clear Data Range','Start to This Frame','This Frame to End','Start to This Frame');
                      if isempty(ropt);return;end
                      switch ropt
                          case 'Start to This Frame'
                              newdata(1:state.vid.ix) = nan;
                          case 'This Frame to End'
                              newdata(state.vid.ix:end) = nan;
                      end
                  case 'All'
                      newdata = nan(size(newdata));
              end
              ui.trackheadcheck.Value = false;
              updateacquisition(ui.trackheadcheck,[]);
              state.track.head.angle = newdata;
           case ui.clearabdbutton
              opt = questdlg('Clear Abdomen Data?','Clear Abdomen Data','This Frame','Range','All','This Frame');
              if isempty(opt);return;end
              newdata = state.track.abd.angle;
              switch opt
                  case 'This Frame'
                      newdata(state.vid.ix) = nan;
                  case 'Range'
                      ropt = questdlg('Clear Abdomen Data Range?','Clear Data Range','Start to This Frame','This Frame to End','Start to This Frame');
                      if isempty(ropt);return;end
                      switch ropt
                          case 'Start to This Frame'
                              newdata(1:state.vid.ix) = nan;
                          case 'This Frame to End'
                              newdata(state.vid.ix:end) = nan;
                      end
                  case 'All'
                      newdata = nan(size(newdata));
              end
              ui.trackabdcheck.Value = false;
              updateacquisition(ui.trackabdcheck,[]);
              state.track.abd.angle = newdata;
           case ui.clearwingsbutton
              opt = questdlg('Clear Wing Data?','Clear Wing Data','This Frame','Range','All','This Frame');
              if isempty(opt);return;end
              newdata = state.track.wing.angle;
              switch opt
                  case 'This Frame'
                      newdata(:,state.vid.ix) = nan;
                  case 'Range'
                      ropt = questdlg('Clear Wing Data Range?','Clear Data Range','Start to This Frame','This Frame to End','Start to This Frame');
                      if isempty(ropt);return;end
                      switch ropt
                          case 'Start to This Frame'
                              newdata(:,1:state.vid.ix) = nan;
                          case 'This Frame to End'
                              newdata(:,state.vid.ix:end) = nan;
                      end
                  case 'All'
                      newdata = nan(size(newdata));
              end 
              ui.trackwingcheck.Value = false;
              updateacquisition(ui.trackwingcheck,[]);
              state.track.wing.angle = newdata;
           case ui.clearlegsbutton
              opt = questdlg('Clear Leg Data?','Clear Leg Data','This Frame','Range','All','This Frame');
              if isempty(opt);return;end
              newangle = state.track.leg.angle;
              newtips = state.track.leg.tip;
              switch opt
                  case 'This Frame'
                      newangle(:,state.vid.ix) = nan;
                      newtips(:,state.vid.ix) = nan;
                  case 'Range'
                      ropt = questdlg('Clear Leg Data Range?','Clear Data Range','Start to This Frame','This Frame to End','Start to This Frame');
                      if isempty(ropt);return;end
                      switch ropt
                          case 'Start to This Frame'
                              newangle(:,1:state.vid.ix) = nan;
                              newtips(:,1:state.vid.ix) = nan;
                          case 'This Frame to End'
                              newangle(:,state.vid.ix:end) = nan;
                              newtips(:,state.vid.ix:end) = nan;
                      end
                  case 'All'
                      newangle = nan(size(newangle));
                      newtips = nan(size(newtips));
              end 
              ui.tracklegcheck.Value = false;
              updateacquisition(ui.tracklegcheck,[]);
              state.track.leg.angle = newangle;
              state.track.leg.tip = newtips;
           otherwise
               disp('!');
       end
       %figure out tabs
        if tabchanged
            for i = 1:length(c)
               set(t{i},'Parent',ui.tabstorage);
               if c{i}.Value
                   set(t{i},'Parent',ui.tabs);
               end
            end
            if a.Value
                ui.tabs.SelectedTab = t{ix};
            end
        end
        updatetracking();
    end
    function updatefps(~,~)
            defaultfps = round(vreader.FrameRate);
            message = ['Input FPS: (from file: ' num2str(defaultfps) ')'];
%             message = sprintf(message);
            value = inputdlg(message,'',[1,30],{num2str(state.vid.fps)});
            if ~isempty(value) && all(isstrprop(strip(value{1}),'digit'))
                value = str2num(value{1});
                if value>0
                    state.vid.fps = value;
                    state.track.ts = linspace(0,state.vid.nframes/value,state.vid.nframes);
                    plotdata;
                    ui.fpsdisplay.String = [num2str(value) 'FPS'];
                else
                    return
                end
            else
                return
            end
    end
%% wing tracking ui functions
    function updatewingtracking(w,~)
        
        if  any([ui.wingl1adjust,ui.wingl2adjust,ui.wingu1adjust,ui.wingu2adjust]==w)
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
            case ui.overlaywingscheck
                state.track.wing.show.thresh = w.Value;
            case ui.lockwingscheck
                if state.track.wing.lock~=w.Value
                    %don't flip this unless the state actually changes
                    ui.wingml1adjust.Value = 100-ui.wingml1adjust.Value;
                end 
                state.track.wing.lock = w.Value;
                
                if state.track.wing.lock
                    enset = 'off';
                    tosync = {ui.wingml1adjust,ui.wingap1adjust,ui.wingt1adjust,...
                      ui.wingo1adjust,ui.winge1adjust,ui.wingn1adjust,...
                      ui.wingu1adjust,ui.wingl1adjust};
                    for ix = 1:length(tosync)
                        updatewingtracking(tosync{ix},[]);
                    end
                else
                    enset = 'on';                    
                end
                ui.wingap2adjust.Enable = enset;
                ui.wingml2adjust.Enable = enset;
                ui.wingt2adjust.Enable = enset;
                ui.wingo2adjust.Enable = enset;
                ui.winge2adjust.Enable = enset;
                ui.wingn2adjust.Enable = enset;
                ui.wingu2adjust.Enable = enset;
                ui.wingl2adjust.Enable = enset;
                
            case ui.wingnormdropdown
                state.track.wing.norm = w.Value;
            case ui.wingml1adjust
                ml = w.Value;
                if state.track.wing.lock
                    state.track.wing.ml(2) = ml;
                    ui.wingml2adjust.Value = ml;
                    ui.wingml2setdisplay.String = [num2str((ml)) '% rootML'];
                else
                    ml = 100-ml;
                end
                state.track.wing.ml(1) = ml;
                ui.wingml1setdisplay.String = [num2str((ml)) '% rootML'];
            
            case ui.wingml2adjust
                state.track.wing.ml(2) = w.Value;
                ui.wingml2setdisplay.String = [num2str(w.Value) '% rootML'];
            case ui.wingap1adjust
                ap = w.Value;
                state.track.wing.ap(1) = ap;
                ui.wingap1setdisplay.String = [num2str(100-ap) '% rootAP'];
                if state.track.wing.lock
                    state.track.wing.ap(2) = ap;
                    ui.wingap2adjust.Value = ap;
                    ui.wingap2setdisplay.String = [num2str(100-ap) '% rootAP'];
                end
            case ui.wingap2adjust
                state.track.wing.ap(2) = w.Value;
                ui.wingap2setdisplay.String = [num2str(100-w.Value) '% rootAP'];
            case ui.wingt1adjust
                state.track.wing.thresh(1) = w.Value;
                if state.track.wing.lock 
                    state.track.wing.thresh(2) = w.Value;
                    ui.wingt2adjust.Value = w.Value;
                    ui.wingt2setdisplay.String = [num2str(state.track.wing.thresh(2)*100) '% thresh'];
                end
                ui.wingt1setdisplay.String = [num2str(state.track.wing.thresh(1)*100) '% thresh'];
            case ui.wingt2adjust
                state.track.wing.thresh(2) = w.Value;
                ui.wingt2setdisplay.String = [num2str(state.track.wing.thresh(2)*100) '% thresh'];
            case ui.wingo1adjust
                state.track.wing.offset(1) = w.Value;
                if state.track.wing.lock 
                    state.track.wing.offset(2) = w.Value;
                    ui.wingo2adjust.Value = w.Value;
                    ui.wingo2setdisplay.String = [num2str(state.track.wing.offset(2)) 'px offset'];
                end
                ui.wingo1setdisplay.String = [num2str(state.track.wing.offset(1)) 'px offset'];
            case ui.wingo2adjust
                state.track.wing.offset(2) = w.Value;
                ui.wingo2setdisplay.String = [num2str(state.track.wing.offset(2)) 'px offset'];
            case ui.winge1adjust
                state.track.wing.extent(1) = w.Value;
                if state.track.wing.lock 
                    state.track.wing.extent(2) = w.Value;
                    ui.winge2adjust.Value = w.Value;
                    ui.winge2setdisplay.String = [num2str(state.track.wing.extent(2)) 'px extent'];
                end
                ui.winge1setdisplay.String = [num2str(state.track.wing.extent(1)) 'px extent'];
            case ui.winge2adjust
                state.track.wing.extent(2) = w.Value;
                ui.winge2setdisplay.String = [num2str(state.track.wing.extent(2)) 'px extent'];
            case ui.wingn1adjust
                n=w.Value;
                ui.wingn1setdisplay.String = [num2str(n) 'px tracked'];
                if state.track.wing.lock 
                    state.track.wing.npts(2) = n;
                    ui.wingn2adjust.Value = n;
                    ui.wingn2setdisplay.String = [num2str(n) 'px tracked'];
                end
                state.track.wing.npts(1) = n;
            case ui.wingn2adjust
                n=w.Value;
                state.track.wing.npts(2) = n;
                ui.wingn2setdisplay.String = [num2str(n) 'px tracked'];
            case ui.wingl1adjust
                l=w.Value;
                ui.wingl1setdisplay.String = [num2str(360-l) '° lower'];
                state.track.wing.ltheta(1) = l;
                if state.track.wing.lock
                    u = wrapTo360(180+(360-l));
                    ui.wingu2setdisplay.String = [num2str(360-u) '° upper'];
                    ui.wingu2adjust.Value = u;
                end
            case ui.wingl2adjust
                l=w.Value;
                state.track.wing.ltheta(2) = l;
                ui.wingl2setdisplay.String = [num2str(360-l) '° lower'];
            case ui.wingu1adjust
                u=w.Value;
                ui.wingu1setdisplay.String = [num2str(360-u) '° upper'];
                state.track.wing.utheta(1) = u;
                if state.track.wing.lock
                    l = wrapTo360(180+(360-u));
                    state.track.wing.ltheta(2) = l;
                    ui.wingl2setdisplay.String = [num2str(360-l) '° lower'];
                end
            case ui.wingu2adjust
                u=w.Value;
                ui.wingu2setdisplay.String = [num2str(360-u) '° upper'];
                state.track.wing.utheta(2) = u;
        end
        
        if boundschanged
            % check if bounds have reversed
            if ui.wingu1adjust.Value<=ui.wingl1adjust.Value
                state.track.wing.utheta(1) = ui.wingu1adjust.Value+360;
            else
                state.track.wing.utheta(1) = ui.wingu1adjust.Value;
            end
            if ui.wingu2adjust.Value<=ui.wingl2adjust.Value
                state.track.wing.utheta(2) = ui.wingu2adjust.Value+360;
            else
                state.track.wing.utheta(2) = ui.wingu2adjust.Value;
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
        switch h
            case ui.headmethoddropdown
                state.track.head.method = h.Value;
            case ui.headnormdropdown
                state.track.head.norm = h.Value;
            case ui.overlayheadcheck
                state.track.head.show.thresh = h.Value;
            case ui.headtadjust
                t=h.Value;
                ui.headtsetdisplay.String = [num2str(t*100) '% thresh'];
                state.track.head.thresh = t;
            case ui.headoadjust
                o=h.Value;
                ui.headosetdisplay.String = [num2str(o) 'px offset'];
                state.track.head.offset = o;
            case ui.headeadjust
                e=h.Value;
                ui.headesetdisplay.String = [num2str(e) 'px extent'];
                state.track.head.extent = e;
            case ui.headnadjust
                n=h.Value;
                ui.headnsetdisplay.String = [num2str(n) 'px tracked'];
                state.track.head.npts = n;
            case ui.headladjust
                l=h.Value;
                ui.headlsetdisplay.String = [num2str(360-l) '° lower'];
                state.track.head.ltheta = l;
            case ui.headuadjust
                u=h.Value;
                ui.headusetdisplay.String = [num2str(360-u) '° upper'];
                state.track.head.utheta = u;
        end
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
        switch a
            case ui.abdnormdropdown
                state.track.abd.norm = a.Value;
            case ui.overlayabdcheck
                state.track.abd.show.thresh = a.Value;
            case ui.abdtadjust
                t=a.Value;
                ui.abdtsetdisplay.String = [num2str(t*100) '% thresh'];
                state.track.abd.thresh = t;
            case ui.abdoadjust
                o=a.Value;
                ui.abdosetdisplay.String = [num2str(o) 'px offset'];
                state.track.abd.offset = o;
            case ui.abdeadjust
                e=a.Value;
                ui.abdesetdisplay.String = [num2str(e) 'px extent'];
                state.track.abd.extent = e;
            case ui.abdnadjust
                n=a.Value;
                ui.abdnsetdisplay.String = [num2str(n) 'px tracked'];
                state.track.abd.npts = n;
            case ui.abdladjust
                l=a.Value;
                ui.abdlsetdisplay.String = [num2str(360-l) '° lower'];
                state.track.abd.ltheta = l;
            case ui.abduadjust
                u=a.Value;
                ui.abdusetdisplay.String = [num2str(360-u) '° upper'];
                state.track.abd.utheta = u;
        end
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
%% leg tracking ui functions
    function updatelegtracking(lg,~)
        switch lg
            case ui.legnormdropdown
                state.track.leg.norm = lg.Value;
            case ui.overlaylegcheck
                state.track.leg.show.thresh = lg.Value;
            case ui.clearlegbordercheck
                state.track.leg.clearborder = lg.Value;
            case ui.legapadjust
                ap = lg.Value*100;
                state.track.leg.ap = ap;
                ui.legapsetdisplay.String = [num2str(100-ap) '% AP'];
            case ui.legtiadjust
                t=lg.Value;
                ui.legtisetdisplay.String = [num2str(t*100) '% threshInt'];
                state.track.leg.threshint = t;
            case ui.legoadjust
                o=lg.Value;
                ui.legosetdisplay.String = [num2str(o) 'px offset'];
                state.track.leg.offset = o;
            case ui.legeadjust
                e=lg.Value;
                ui.legesetdisplay.String = [num2str(e) 'px extent'];
                state.track.leg.extent = e;
            case ui.legtsadjust
                n=lg.Value;
                ui.legtssetdisplay.String = [num2str(n) 'px threshSz'];
                state.track.leg.threshsize = n;
            case ui.legspnadjust
                span=180-lg.Value;
                ui.legspnsetdisplay.String = [num2str(180-span) '° span'];
                state.track.leg.ltheta = 180+span/2;
                state.track.leg.utheta = 360-span/2;
        end
        updatetracking();
    end
    function makelegmask()
        lr = double(mean(state.track.leg.root));
        r1 = state.track.leg.offset;
        r2 = state.track.leg.offset+state.track.leg.extent;
        lt = state.track.leg.ltheta+state.track.orientation;
        rt = state.track.leg.utheta+state.track.orientation;
        w = state.vid.width;
        h = state.vid.height;
        shift = state.track.orientation;
        [mask, poly] = make_arc_mask(lr(1),lr(2),r1,r2,lt,rt,w,h,1,1.75,shift);
        state.track.leg.mask = mask;
        state.track.leg.poly = poly;
        bordermask = bwmorph(mask,'remove');
        bordermask([1 h],:)=0;
        bordermask(:,[1 w])=0;
        state.track.leg.borderidx = find(imdilate(bordermask,ones(5)));
    end
%% plotting function
    function plotdata()
        if ~state.showdata;return;end
        data = [];
        titles = {};
        pcolors = {};
        di = 0;
        correct = state.track.orientation;
        if ui.plotheadcheck.Value
            di = di+1;
            seg = wrapTo360(state.track.head.angle+correct);
            jumpix=abs(diff(seg))>180;
            seg(jumpix) = nan;
            data = [data; seg];            
            titles{di} = 'Head';
            pcolors{di} = colors.head./255;
        end
        if ui.plotwingcheck.Value
            di = di+1;
            seg = wrapTo360(state.track.wing.angle(1,:)+correct);
            jumpix=abs(diff(seg))>180;
            seg(jumpix) = nan;
            data = [data; seg];
            titles{di} = 'Left Wing';
            pcolors{di} = colors.wingL./255;
            
            di = di+1;
            seg = wrapTo360(state.track.wing.angle(2,:)+correct);
            jumpix=abs(diff(seg))>180;
            seg(jumpix) = nan;
            data = [data; seg];
            titles{di} = 'Right Wing';
            pcolors{di} = colors.wingR./255;
        end
        if ui.plotabdcheck.Value
            di = di+1;
            seg = wrapTo360(state.track.abd.angle+correct);
            jumpix=abs(diff(seg))>180;
            seg(jumpix) = nan;
            data = [data; seg];
            titles{di} = 'Abdomen';
            pcolors{di} = colors.abd./255;
        end
        if ui.plotlegcheck.Value
            di = di+1;
            seg = wrapTo360(state.track.leg.angle(1,:)+correct);
            jumpix=abs(diff(seg))>180;
            seg(jumpix) = nan;
            data = [data; seg];
            titles{di} = 'Left Leg';
            pcolors{di} = colors.leg./255;
            
            di = di+1;
            seg = wrapTo360(state.track.leg.angle(2,:)+correct);
            jumpix=abs(diff(seg))>180;
            seg(jumpix) = nan;
            data = [data; seg];
            titles{di} = 'Right Leg';
            pcolors{di} = colors.leg./255;
        end
        
        if di==0
            return;
        end
        
        if strcmp(tf.Visible,'off');tf.Visible = 'on';end
        useix = strcmp(ui.ixtbtn.String,'t');
        if useix
            t = 1:length(state.track.ts);
            tunit = 'frames';
        else
            t = state.track.ts;    
            tunit = 's';
        end
        lines = plot(datax,t,data);hold(datax,'on')
        [lines.Color] = deal(pcolors{:});
        [lines.ButtonDownFcn] = deal(@playctrl);
        if useix
            x = state.vid.ix;
        else
            x = state.vid.ix/state.vid.fps;
        end
        plot(datax,[x x],[0 360],'Color','Black');hold(datax,'off')
        datax.HitTest = 'on';
        datax.ButtonDownFcn = @playctrl;
        ylim(datax,[0 360])
        yticks(datax,0:30:360);
        if strcmp(ui.zoombtn.String,'Z-')
            if useix
                f = state.vid.ix;
                xlim(datax,[f-state.vid.fps*.4 f+state.vid.fps*.1]);
            else
                f = state.vid.ix/state.vid.fps;
                xlim(datax,[f-.4 f+.1]);
            end
        elseif useix
            xlim(datax,[1,length(t)]);
        else
            xlim(datax,[0 state.vid.nframes/state.vid.fps]);
        end
        hold(datax,'off')
        box(datax,'off');
        xlabel(datax,['Time (' tunit ')']);
        ylabel(datax,'Angle (°)');
    end
%% utility functions
    function state = initializestatevariables()
        state = struct;
        state.showdata = false;
        
        state.vid.path = pwd;
        state.vid.basename = '';
        state.vid.ext = '';
        state.vid.ix = 1;
        state.vid.loop = false;
        state.vid.invertbw = false;
        
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
        state.track.head.check = false;
        state.track.head.show.pts = true;
        state.track.head.show.thresh = false;
        state.track.head.show.poly = true;
        state.track.head.show.check = false;
        
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
        state.track.abd.check = false;
        state.track.abd.show.pts = true;
        state.track.abd.show.thresh = false;
        state.track.abd.show.poly = true;
        state.track.abd.show.check = false;
        
        state.track.leg.angle = [];
        state.track.leg.tip = [];
        state.track.leg.root = [];
        state.track.leg.mask = [];
        state.track.leg.poly = [];
        state.track.leg.clearborder = true;
        state.track.leg.borderidx = [];
        state.track.leg.ap  = 50;
        state.track.leg.threshint = .4;
        state.track.leg.threshsize = 150;
        state.track.leg.norm = 1;
        state.track.leg.offset = 45;
        state.track.leg.eccen = 1.75;
        state.track.leg.extent = 50;
        state.track.leg.ltheta = 200;
        state.track.leg.utheta = 340;
        state.track.leg.check = false;
        state.track.leg.show.pts = true;
        state.track.leg.show.thresh = true;
        state.track.leg.show.poly = true;
        state.track.leg.show.check = false;
        
        state.track.wing.angle = [];
        state.track.wing.root = [];
        state.track.wing.mask = [];
        state.track.wing.poly = [];
        state.track.wing.ap = [25 25];
        state.track.wing.ml = [50 50];
        state.track.wing.thresh = [.1 .1];
        state.track.wing.norm = 2;
        state.track.wing.offset = [80 80];
        state.track.wing.extent = [30 30];
        state.track.wing.ltheta = [150 275];
        state.track.wing.utheta = [265 390];
        state.track.wing.npts = [70 70];
        state.track.wing.lock = true;
        state.track.wing.check = false;
        state.track.wing.show.pts = true;
        state.track.wing.show.thresh = true;
        state.track.wing.show.poly = true;
        state.track.wing.show.check = false;
    end
    function ui = initializeuicontrols(ui)
        %% vidpanel and load button ui init
        if nargin<1
            ui = struct;
        end
        
        ui.exportbutton = uicontrol(cf,'Style','pushbutton','String',...
            'Export to Workspace','Position',[0 0 125 45],'Callback',@savedata);
        
        ui.savebutton = uicontrol(cf,'Style','pushbutton','String',...
            'Save to Disk','Position',[125 0 125 45],'Callback',@savedata);
        
        ui.loadbutton = uicontrol(cf,'Style','pushbutton','String',...
            'Load File','Position',[0 0 250 500],'Callback',@loadbtn);
        
        ui.vidpanel = uipanel(cf,'Title',' ','Units','pixels',...
            'Position',[63 430 187 70],'BorderType','none','Visible','off');
        
        ui.playpause = uicontrol(ui.vidpanel,'Style','pushbutton','String',...
            '>','Position',[2 28 30 40],...
            'Callback',@playctrl,'Interruptible','on');
        
        ui.stopbutton = uicontrol(ui.vidpanel,'Style','pushbutton','String',...
            '[]','Position',[32 28 20 40],...
            'Callback',@playctrl);
        
        ui.dispframe = uicontrol(ui.vidpanel,'Style', 'edit',...
            'String','','ButtonDownFcn',@playctrl,...
            'Position', [54 48 131 20],'Enable','off');
        
        ui.progress = uicontrol(ui.vidpanel,'Style','slider', 'Min',1,'Max',2,'Value',1,...
            'SliderStep',[1/(2-1) 1/(2-1)],...
            'Position',[54 28 131 20],'Callback',@playctrl);
        
        ui.loopcheck = uicontrol(ui.vidpanel,'Style', 'checkbox','String','Loop',...
            'Value',state.vid.loop,'Position', [3 3 50 20],'Callback',@playctrl);
        
        ui.invertcheck = uicontrol(ui.vidpanel,'Style', 'checkbox','String','Invert',...
            'Value',state.vid.invertbw,'Position', [51 3 60 20],...
            'Callback',@updateacquisition);
        
        ui.fpsdisplay = uicontrol(ui.vidpanel,'Style','edit','Enable','off',...,
            'String',[],'Position',[102 2 80 20],'ButtonDownFcn',@updatefps);
        
        %% acquisition tabs ui init
        
        ui.setuppanel = uipanel('Parent', cf, 'Title', '','Visible','off',...
            'BorderType','none','Units','Pixels','Position',[0 283 250 145]);
        ui.tabs = uitabgroup('Parent', cf,'Units','Pixels','Visible','off',...
            'Position',[0 45 250 240]);
        ui.tabstorage = uitabgroup('Parent',cf,'Visible','off');
        
        ui.wingtab = uitab('Parent', ui.tabstorage, 'Title', 'Wings');
        ui.headtab = uitab('Parent', ui.tabstorage, 'Title', 'Head');
        ui.abdtab = uitab('Parent', ui.tabstorage, 'Title', 'Abdomen');
        ui.legtab = uitab('Parent', ui.tabstorage,'Title', 'Legs');
        
        %% acquisition control ui init
        
        ui.axistitle = uicontrol(ui.setuppanel,'Style', 'text','FontWeight','Bold',...
            'Position', [5 120 100 20],'String','Define Body Axis');
        
        ui.headroottext = uicontrol(ui.setuppanel,'Style', 'text',...
            'Position', [5 100 60 20],'String','Head Root',...
            'HorizontalAlignment','right');
        ui.headsetdisplay = uicontrol(ui.setuppanel,'Style','edit','String',...
            [],'Position',[90 102 70 20],'Enable','off');
        
        ui.headrootxadjust = uicontrol(ui.setuppanel,'Style', 'slider','Value',0,...
            'Position', [70 102 20 19],'Enable','off','Callback',@updateacquisition);
        ui.headrootyadjust = uicontrol(ui.setuppanel,'Style', 'slider','Value',0,...
            'Position', [160 102 20 20],'Enable','off','Callback',@updateacquisition);
        ui.headptbutton = uicontrol(ui.setuppanel,'Style','pushbutton','String',...
            'Pick','Position',[190 102 50 20],'Callback',@updateacquisition);
        
        ui.abdroottext = uicontrol(ui.setuppanel,'Style', 'text',...
            'Position', [5 80 60 20],'String','Abd. Root',...
            'HorizontalAlignment','right');
        ui.abdsetdisplay = uicontrol(ui.setuppanel,'Style','edit','String',...
            [],'Position',[90 82 70 20],'Enable','off');
        ui.abdrootxadjust = uicontrol(ui.setuppanel,'Style', 'slider','Value',0,...
            'Position', [70 82 20 19],'Enable','off','Callback',@updateacquisition);
        ui.abdrootyadjust = uicontrol(ui.setuppanel,'Style', 'slider','Value',0,...
            'Position', [160 82 20 20],'Enable','off','Callback',@updateacquisition);
        ui.abdptbutton = uicontrol(ui.setuppanel,'Style','pushbutton','String',...
            'Pick','Position',[190 82 50 20],'Callback',@updateacquisition);
        
        ui.trackpanel = uipanel(ui.setuppanel,'Units','pixels','Title','Track Body Parts',...
            'FontWeight','bold','Position',[3 3 243 76],'Visible','off');
        
        ui.tracktext = uicontrol(ui.trackpanel,'Style', 'text',...
            'Position', [7 25 40 15],'String','Track:',...
            'HorizontalAlignment','right');
        
        ui.plottext = uicontrol(ui.trackpanel,'Style', 'text',...
            'Position', [7 5 40 15],'String','Plot:',...
            'HorizontalAlignment','right');
        
        ui.trackwingtext = uicontrol(ui.trackpanel,'Style', 'text',...
            'Position', [55 37 50 20],'String','Wings',...
            'HorizontalAlignment','left');
        ui.trackwingcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [65 23 20 20],'Callback',@updateacquisition);
        ui.plotwingcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [65 3 20 20],'Callback',@updateacquisition);
        
        ui.trackheadtext = uicontrol(ui.trackpanel,'Style', 'text',...
            'Position', [109 37 50 20],'String','Head',...
            'HorizontalAlignment','left');
        ui.trackheadcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [114 23 20 20],'Callback',@updateacquisition);
        ui.plotheadcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [114 3 20 20],'Callback',@updateacquisition);
        
        ui.trackabdtext = uicontrol(ui.trackpanel,'Style', 'text',...
            'Position', [148 37 50 20],'String','Abdomen',...
            'HorizontalAlignment','left');
        ui.trackabdcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [163 23 20 20],'Callback',@updateacquisition);
        ui.plotabdcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [163 3 20 20],'Callback',@updateacquisition);
        
        ui.tracklegtext = uicontrol(ui.trackpanel,'Style', 'text',...
            'Position', [209 37 50 20],'String','Legs',...
            'HorizontalAlignment','left');
        ui.tracklegcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [212 23 20 20],'Callback',@updateacquisition);
        ui.plotlegcheck = uicontrol(ui.trackpanel,'Style', 'checkbox',...
            'Position', [212 3 20 20],'Callback',@updateacquisition);
        
        %% wing tracking ui init
        
        ui.leftwingtext = uicontrol(ui.wingtab,'Style', 'text',...
            'Position', [33 190 70 20],'String','Left Wing',...
            'FontWeight','bold','HorizontalAlignment','left');
        
        ui.rightwingtext = uicontrol(ui.wingtab,'Style', 'text',...
            'Position', [158 190 70 20],'String','Right Wing',...
            'FontWeight','bold','HorizontalAlignment','left');
        
        ui.wingnormdropdown = uicontrol(ui.wingtab,'Style','popupmenu','String',...
            {'no norm','ROI norm','Full norm'},'Tooltip','Histogram Normalization Options',...
            'Value',state.track.wing.norm,'Position',[3 7 70 17],...
            'Callback',@updatewingtracking);
        
        ui.overlaywingscheck = uicontrol(ui.wingtab,'Style','checkbox','String',...
            'BW','Value',state.track.wing.show.thresh,'Tooltip','Overlay Thresholded ROI',...
            'Position', [80 3 60 20],'Callback',@updatewingtracking);
        
        ui.lockwingscheck = uicontrol(ui.wingtab,'Style', 'checkbox','String',...
            'Sync','Value',state.track.wing.lock,'Tooltip','Sync Left and Right Wing Settings',...
            'Position', [130 3 60 20],'Callback',@updatewingtracking);
        
        ui.clearwingsbutton = uicontrol(ui.wingtab,'Style','pushbutton','String',...
            'Clear Data','Position',[180 1 63 24],'Callback',@updateacquisition);
        
        ui.wingap1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.ap(1),'Position', [3 173 20 20],...
            'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
            'Callback',@updatewingtracking);
        ui.wingap2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.ap(2),'Position', [128 173 20 20],...
            'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
            'Callback',@updatewingtracking);
        ui.wingap1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(100-ui.wingap1adjust.Value) '% rootAP'],...
            'Position',[23 173 95 20],'Enable','off');
        ui.wingap2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(100-ui.wingap2adjust.Value) '% rootAP'],...
            'Position',[148 173 95 20],'Enable','off');
        
        ui.wingml1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.ml(1),'Position', [3 152 20 19],...
            'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
            'Callback',@updatewingtracking);
        ui.wingml2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.ml(2),'Position', [128 152 20 19],...
            'Min',0,'Max',100,'SliderStep',[1/100, 1/100],...
            'Callback',@updatewingtracking);
        ui.wingml1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(ui.wingml1adjust.Value) '% rootML'],...
            'Position',[23 152 95 20],'Enable','off');
        ui.wingml2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(ui.wingml2adjust.Value) '% rootML'],...
            'Position',[148 152 95 20],'Enable','off');        
        
        ui.wingt1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.thresh(1)*100) '% thresh'],...
            'Position',[23 131 95 20],'Enable','off');
        ui.wingt2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.thresh(2)*100) '% thresh'],...
            'Position',[148 131 95 20],'Enable','off');
        ui.wingt1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.thresh(1),'Position', [3 131 20 20],...
            'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
            'Callback',@updatewingtracking);
        ui.wingt2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.thresh(2),'Position', [128 131 20 20],...
            'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
            'Callback',@updatewingtracking);
        
        ui.wingo1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.offset(1)) 'px offset'],...
            'Position',[23 110 95 20],'Enable','off');
        ui.wingo2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.offset(2)) 'px offset'],...
            'Position',[148 110 95 20],'Enable','off');
        ui.wingo1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.offset(1),'Position', [3 110 20 20],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updatewingtracking);
        ui.wingo2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.offset(2),'Position', [128 110 20 20],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updatewingtracking);
        
        ui.winge1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.extent(1)) 'px extent'],...
            'Position',[23 89 95 20],'Enable','off');
        ui.winge2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.extent(2)) 'px extent'],...
            'Position',[148 89 95 20],'Enable','off');
        ui.winge1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.extent(1),'Position', [3 89 20 20],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updatewingtracking);
        ui.winge2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.extent(2),'Position', [128 89 20 20],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updatewingtracking);
        
        ui.wingn1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.npts(1)) 'px tracked'],...
            'Position',[23 68 95 20],'Enable','off');
        ui.wingn2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(state.track.wing.npts(2)) 'px tracked'],...
            'Position',[148 68 95 20],'Enable','off');
        ui.wingn1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.npts(1),'Position', [3 68 20 20],...
            'Min',0,'Max',400,'SliderStep',[1/400, 1/40],...
            'Callback',@updatewingtracking);
        ui.wingn2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.npts(2),'Position', [128 68 20 20],...
            'Min',0,'Max',400,'SliderStep',[1/400, 1/40],...
            'Callback',@updatewingtracking);
        
        ui.wingu1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(360-state.track.wing.utheta(1)) '° upper'],...
            'Position',[23 47 95 20],'Enable','off');
        ui.wingl2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(360-state.track.wing.ltheta(2)) '° lower'],...
            'Position',[148 47 95 20],'Enable','off');
        ui.wingu1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.utheta(1),'Position', [3 47 20 19],...
            'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
            'Callback',@updatewingtracking);
        ui.wingl2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.ltheta(2),'Position', [128 47 20 19],...
            'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
            'Callback',@updatewingtracking);
        
        ui.wingl1setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(360-state.track.wing.ltheta(1)) '° lower'],...
            'Position',[23 26 95 20],'Enable','off');
        ui.wingu2setdisplay = uicontrol(ui.wingtab,'Style','edit','String',...
            [num2str(wrapTo360(360-state.track.wing.utheta(2))) '° upper'],...
            'Position',[148 26 95 20],'Enable','off');
        ui.wingl1adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.ltheta(1),'Position', [3 26 20 19],...
            'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
            'Callback',@updatewingtracking);
        ui.wingu2adjust = uicontrol(ui.wingtab,'Style', 'slider',...
            'Value',state.track.wing.utheta(2)-360,'Position', [128 26 20 19],...
            'Min',-1,'Max',360,'SliderStep',[1/361, 1/361],...
            'Callback',@updatewingtracking);
        
        %% head tracking ui init
        
        ui.headmethodtext = uicontrol(ui.headtab,'Style','text','FontWeight','Bold',...
            'Position', [154 174 90 30],'String','Tip-Tracking Method');
        
        ui.headmethoddropdown = uicontrol(ui.headtab,'Style','popupmenu','String',...
            {'distribution','k-means'},'Value',state.track.head.method,...
            'Position',[159 151 80 22],'Callback',@updateheadtracking);
        
        ui.headnormtext = uicontrol(ui.headtab,'Style', 'text','FontWeight','Bold',...
            'Position', [154 109 90 30],'String','Histogram Normalization');
        
        ui.headnormdropdown = uicontrol(ui.headtab,'Style','popupmenu','String',...
            {'none','ROI only','full image'},'Value',state.track.head.norm,...
            'Position',[159 86 80 22],'Callback',@updateheadtracking);
        
        ui.overlayheadcheck = uicontrol(ui.headtab,'Style','checkbox','String',...
            'Overlay BW','Value',state.track.head.show.thresh,...,
            'Tooltip','Overlay Thresholded ROI',...
            'Position', [159 64 80 20],'Callback',@updateheadtracking);
        
        ui.clearheadbutton = uicontrol(ui.headtab,'Style','pushbutton','String',...
            'Clear Data','Position',[159 6 80 50],'Callback',@updateacquisition);
        
        ui.headtsetdisplay = uicontrol(ui.headtab,'Style','edit','String',...
            [num2str(state.track.head.thresh*100) '% thresh'],...
            'Position',[33 176 120 30],'Enable','off');
        ui.headtadjust = uicontrol(ui.headtab,'Style', 'slider',...
            'Value',state.track.head.thresh,'Position', [3 176 30 30],...
            'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
            'Callback',@updateheadtracking);
        
        ui.headosetdisplay = uicontrol(ui.headtab,'Style','edit','String',...
            [num2str(state.track.head.offset) 'px offset'],...
            'Position',[33 142 120 30],'Enable','off');
        ui.headoadjust = uicontrol(ui.headtab,'Style', 'slider',...
            'Value',state.track.head.offset,'Position', [3 142 30 30],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updateheadtracking);
        
        ui.headesetdisplay = uicontrol(ui.headtab,'Style','edit','String',...
            [num2str(state.track.head.extent) 'px extent'],...
            'Position',[33 108 120 30],'Enable','off');
        ui.headeadjust = uicontrol(ui.headtab,'Style', 'slider',...
            'Value',state.track.head.extent,'Position', [3 108 30 30],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updateheadtracking);
        
        ui.headnsetdisplay = uicontrol(ui.headtab,'Style','edit','String',...
            [num2str(state.track.head.npts) 'px tracked'],...
            'Position',[33 74 120 30],'Enable','off');
        ui.headnadjust = uicontrol(ui.headtab,'Style', 'slider',...
            'Value',state.track.head.npts,'Position', [3 74 30 30],...
            'Min',0,'Max',400,'SliderStep',[1/400, 1/40],...
            'Callback',@updateheadtracking);
        
        ui.headusetdisplay = uicontrol(ui.headtab,'Style','edit','String',...
            [num2str(360-state.track.head.utheta) '° upper'],...
            'Position',[33 40 120 30],'Enable','off');
        ui.headuadjust = uicontrol(ui.headtab,'Style', 'slider',...
            'Value',state.track.head.utheta,'Position', [3 40 30 29],...
            'Min',270,'Max',360,'SliderStep',[1/90, 1/9],...
            'Callback',@updateheadtracking);
        
        ui.headlsetdisplay = uicontrol(ui.headtab,'Style','edit','String',...
            [num2str(360-state.track.head.ltheta) '° lower'],...
            'Position',[33 6 120 30],'Enable','off');
        ui.headladjust = uicontrol(ui.headtab,'Style', 'slider',...
            'Value',state.track.head.ltheta,'Position', [3 6 30 29],...
            'Min',180,'Max',270,'SliderStep',[1/90, 1/90],...
            'Callback',@updateheadtracking);
        
        %% abdomen tracking ui init
        
        ui.abdnormtext = uicontrol(ui.abdtab,'Style', 'text','FontWeight','Bold',...
            'Position', [154 174 90 30],'String','Histogram Normalization');
        
        ui.abdnormdropdown = uicontrol(ui.abdtab,'Style','popupmenu','String',...
            {'none','ROI only','full image'},'Value',state.track.abd.norm,...
            'Position',[159 151 80 22],'Callback',@updateabdtracking);
        
        ui.overlayabdcheck = uicontrol(ui.abdtab,'Style','checkbox','String',...
            'Overlay BW','Value',state.track.abd.show.thresh,...,
            'Tooltip','Overlay Thresholded ROI',...
            'Position', [159 129 80 20],'Callback',@updateabdtracking);
        
        ui.clearabdbutton = uicontrol(ui.abdtab,'Style','pushbutton','String',...
            'Clear Data','Position',[159 6 80 50],'Callback',@updateacquisition);
        
        ui.abdtsetdisplay = uicontrol(ui.abdtab,'Style','edit','String',...
            [num2str(state.track.abd.thresh*100) '% thresh'],...
            'Position',[33 176 120 30],'Enable','off');
        ui.abdtadjust = uicontrol(ui.abdtab,'Style', 'slider',...
            'Value',state.track.abd.thresh,'Position', [3 176 30 30],...
            'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
            'Callback',@updateabdtracking);
        
        ui.abdosetdisplay = uicontrol(ui.abdtab,'Style','edit','String',...
            [num2str(state.track.abd.offset) 'px offset'],...
            'Position',[33 142 120 30],'Enable','off');
        ui.abdoadjust = uicontrol(ui.abdtab,'Style', 'slider',...
            'Value',state.track.abd.offset,'Position', [3 142 30 30],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updateabdtracking);
        
        ui.abdesetdisplay = uicontrol(ui.abdtab,'Style','edit','String',...
            [num2str(state.track.abd.extent) 'px extent'],...
            'Position',[33 108 120 30],'Enable','off');
        ui.abdeadjust = uicontrol(ui.abdtab,'Style', 'slider',...
            'Value',state.track.abd.extent,'Position', [3 108 30 30],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updateabdtracking);
        
        ui.abdnsetdisplay = uicontrol(ui.abdtab,'Style','edit','String',...
            [num2str(state.track.abd.npts) 'px tracked'],...
            'Position',[33 74 120 30],'Enable','off');
        ui.abdnadjust = uicontrol(ui.abdtab,'Style', 'slider',...
            'Value',state.track.abd.npts,'Position', [3 74 30 30],...
            'Min',0,'Max',1000,'SliderStep',[1/1000, 1/100],...
            'Callback',@updateabdtracking);
        
        ui.abdusetdisplay = uicontrol(ui.abdtab,'Style','edit','String',...
            [num2str(360-state.track.abd.utheta) '° upper'],...
            'Position',[33 40 120 30],'Enable','off');
        ui.abduadjust = uicontrol(ui.abdtab,'Style', 'slider',...
            'Value',state.track.abd.utheta,'Position', [3 40 30 29],...
            'Min',90,'Max',180,'SliderStep',[1/90, 1/9],...
            'Callback',@updateabdtracking);
        
        ui.abdlsetdisplay = uicontrol(ui.abdtab,'Style','edit','String',...
            [num2str(360-state.track.abd.ltheta) '° lower'],...
            'Position',[33 6 120 30],'Enable','off');
        ui.abdladjust = uicontrol(ui.abdtab,'Style', 'slider',...
            'Value',state.track.abd.ltheta,'Position', [3 6 30 29],...
            'Min',0,'Max',90,'SliderStep',[1/90, 1/90],...
            'Callback',@updateabdtracking);
        
        %% leg tracking ui init
        
        ui.legnormtext = uicontrol(ui.legtab,'Style', 'text','FontWeight','Bold',...
            'Position', [154 174 90 30],'String','Histogram Normalization');
        
        ui.legnormdropdown = uicontrol(ui.legtab,'Style','popupmenu','String',...
            {'none','ROI only','full image'},'Value',state.track.leg.norm,...
            'Position',[159 151 80 22],'Callback',@updatelegtracking);
        
        ui.overlaylegcheck = uicontrol(ui.legtab,'Style','checkbox','String',...
            'Overlay BW','Value',state.track.leg.show.thresh,...,
            'Tooltip','Overlay Thresholded ROI',...
            'Position', [159 129 80 20],'Callback',@updatelegtracking);
        
        ui.clearlegbordercheck = uicontrol(ui.legtab,'Style','checkbox','String',...
            sprintf('Clear Border'),'Value',state.track.leg.clearborder,...,
            'Tooltip','Do not track blobs with majority of extrema on ROI border',...
            'Position', [159 102 80 20],'Callback',@updatelegtracking);
        
        ui.clearlegsbutton = uicontrol(ui.legtab,'Style','pushbutton','String',...
            'Clear Data','Position',[159 6 80 50],'Callback',@updateacquisition);
        
        ui.legtisetdisplay = uicontrol(ui.legtab,'Style','edit','String',...
            [num2str(state.track.leg.threshint*100) '% threshInt'],...
            'Position',[33 176 120 30],'Enable','off');
        ui.legtiadjust = uicontrol(ui.legtab,'Style', 'slider',...
            'Value',state.track.leg.threshint,'Position', [3 176 30 30],...
            'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
            'Callback',@updatelegtracking);
        
        ui.legtssetdisplay = uicontrol(ui.legtab,'Style','edit','String',...
            [num2str(state.track.leg.threshsize) 'px threshSz'],...
            'Position',[33 142 120 30],'Enable','off');
        ui.legtsadjust = uicontrol(ui.legtab,'Style', 'slider',...
            'Value',state.track.leg.threshsize,'Position', [3 142 30 30],...
            'Min',0,'Max',1000,'SliderStep',[1/1000, 1/100],...
            'Callback',@updatelegtracking);
        
        ui.legapsetdisplay = uicontrol(ui.legtab,'Style','edit','String',...
            [num2str(100-state.track.leg.ap) '% AP'],...
            'Position',[33 108 120 30],'Enable','off');
        ui.legapadjust = uicontrol(ui.legtab,'Style', 'slider',...
            'Value',state.track.leg.ap/100,'Position', [3 108 30 30],...
            'Min',0,'Max',1,'SliderStep',[1/100, 1/10],...
            'Callback',@updatelegtracking);
        
        ui.legosetdisplay = uicontrol(ui.legtab,'Style','edit','String',...
            [num2str(state.track.leg.offset) 'px offset'],...
            'Position',[33 74 120 30],'Enable','off');
        ui.legoadjust = uicontrol(ui.legtab,'Style', 'slider',...
            'Value',state.track.leg.offset,'Position', [3 74 30 30],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updatelegtracking);
        
        ui.legesetdisplay = uicontrol(ui.legtab,'Style','edit','String',...
            [num2str(state.track.leg.extent) 'px extent'],...
            'Position',[33 40 120 30],'Enable','off');
        ui.legeadjust = uicontrol(ui.legtab,'Style', 'slider',...
            'Value',state.track.leg.extent,'Position', [3 40 30 30],...
            'Min',0,'Max',200,'SliderStep',[1/200, 1/20],...
            'Callback',@updatelegtracking);
        
        span = state.track.leg.utheta-state.track.leg.ltheta;
        ui.legspnsetdisplay = uicontrol(ui.legtab,'Style','edit','String',...
            [num2str(span) '° span'],...
            'Position',[33 6 120 30],'Enable','off');
        ui.legspnadjust = uicontrol(ui.legtab,'Style', 'slider',...
            'Value',span,'Position', [3 6 30 29],...
            'Min',0,'Max',180,'SliderStep',[1/180, 1/180],...
            'Callback',@updatelegtracking);
        
        %% zoom button
        ui.zoombtn = uicontrol(tf,'Style','pushbutton','String',...
            'Z+','unit','pixel','Position',[462 250 31 50],...
            'Callback',@zoomctrl);
        %% index or time button
        ui.ixtbtn = uicontrol(tf,'Style','pushbutton','String',...
            'ix','unit','pixel','Position',[462 200 31 50],...
            'Callback',@ixtctrl);
    end

    function restoreuicontrols()
        %play controls
        ui.progress.Max = state.vid.nframes;
        ui.progress.SliderStep = [1/(state.vid.nframes-1) 1/(state.vid.nframes-1)];
        ui.loopcheck.Value = state.vid.loop;
        ui.invertcheck.Value = state.vid.invertbw;
        ui.fpsdisplay.String = [num2str(state.vid.fps) 'FPS'];
        
        %body axis setups
        ui.vidpanel.Visible = 'on';
        ui.setuppanel.Visible = 'on';
        ui.headrootxadjust.Max = state.vid.width;
        ui.headrootyadjust.Max = state.vid.height;
        ui.abdrootxadjust.Max = state.vid.width;
        ui.abdrootyadjust.Max = state.vid.height;
        
        %tracking control/tabs
        ui.trackwingcheck.Value = state.track.wing.check;
        ui.trackheadcheck.Value = state.track.head.check;
        ui.trackabdcheck.Value = state.track.abd.check;
        ui.tracklegcheck.Value = state.track.leg.check;
        updateacquisition(ui.trackwingcheck);

        ui.plotwingcheck.Value = state.track.wing.show.check;
        ui.plotheadcheck.Value = state.track.head.show.check;
        ui.plotabdcheck.Value = state.track.abd.show.check;
        ui.plotlegcheck.Value = state.track.leg.show.check;
        updateacquisition(ui.plotwingcheck);
        
        %wings
        ui.wingnormdropdown.Value = state.track.wing.norm;
        ui.overlaywingscheck = state.track.wing.show.thresh;
        ui.lockwingscheck.Value = state.track.wing.lock;
        if state.track.wing.lock
            wenset = 'off';
        else
            wenset = 'on';
        end
        
        ui.wingap1adjust.Value = state.track.wing.ap(1);
        ui.wingap1setdisplay.String = [num2str(100-state.track.wing.ap(1)) '% rootAP'];
        ui.wingap2adjust.Enable = wenset;
        ui.wingap2adjust.Value = state.track.wing.ap(2);
        ui.wingap2setdisplay.String = [num2str(100-state.track.wing.ap(2)) '% rootAP'];
        
        ml = state.track.wing.ml(1);
        if ~state.track.wing.lock
            ml = 100-ml;
        end
        ui.wingml1adjust.Value = ml;
        ui.wingml1setdisplay.String = [num2str(state.track.wing.ml(1)) '% rootML'];
        ui.wingml2adjust.Enable = wenset;
        ui.wingml2adjust.Value = state.track.wing.ml(2);
        ui.wingml2setdisplay.String = [num2str(state.track.wing.ml(2)) '% rootML'];
        
        ui.wingt1adjust.Value = state.track.wing.thresh(1);
        ui.wingt1setdisplay.String = [num2str(state.track.wing.thresh(1)*100) '% thresh'];
        ui.wingt2adjust.Enable = wenset;
        ui.wingt2adjust.Value = state.track.wing.thresh(2);
        ui.wingt2setdisplay.String = [num2str(state.track.wing.thresh(2)*100) '% thresh'];
        
        ui.wingo1adjust.Value = state.track.wing.offset(1);
        ui.wingo1setdisplay.String = [num2str(state.track.wing.offset(1)) 'px offset'];
        ui.wingo2adjust.Enable = wenset;
        ui.wingo2adjust.Value = state.track.wing.offset(2);
        ui.wingo2setdisplay.String = [num2str(state.track.wing.offset(2)) 'px offset'];
        
        ui.winge1adjust.Value = state.track.wing.extent(1);
        ui.winge1setdisplay.String = [num2str(state.track.wing.extent(1)) 'px extent'];
        ui.winge2adjust.Enable = wenset;
        ui.winge2adjust.Value =state.track.wing.extent(2);
        ui.winge2setdisplay.String = [num2str(state.track.wing.extent(2)) 'px extent'];
        
        ui.wingn1adjust.Value =state.track.wing.npts(1);
        ui.wingn1setdisplay.String = [num2str(state.track.wing.npts(1)) 'px tracked'];
        ui.wingn2adjust.Enable = wenset;
        ui.wingn2adjust.Value =state.track.wing.npts(2);
        ui.wingn2setdisplay.String = [num2str(state.track.wing.npts(2)) 'px tracked'];
        
        u = state.track.wing.utheta(1);
        if u>360
            u = u-360; 
        end
        ui.wingu1adjust.Value = u;
        ui.wingu1setdisplay.String = [num2str(wrapTo360(360-state.track.wing.utheta(1))) '° upper'];
        ui.wingl2adjust.Enable = wenset;
        ui.wingl2adjust.Value = state.track.wing.ltheta(2);
        ui.wingl2setdisplay.String = [num2str(360-state.track.wing.ltheta(2)) '° lower'];
        
        ui.wingl1adjust.Value = state.track.wing.ltheta(1);
        ui.wingl1setdisplay.String = [num2str(360-state.track.wing.ltheta(1)) '° lower'];
        ui.wingu2adjust.Enable = wenset;
        u = state.track.wing.utheta(2);
        if u>360
            u = u-360; 
        end
        ui.wingu2adjust.Value = u;
        ui.wingu2setdisplay.String = [num2str(wrapTo360(360-state.track.wing.utheta(2))) '° upper'];
        
        %head
        ui.headmethoddropdown.Value = state.track.head.method;
        ui.headnormdropdown.Value = state.track.head.norm;
        ui.overlayheadcheck.Value = state.track.head.show.thresh;
        
        ui.headtadjust.Value = state.track.head.thresh;
        ui.headtsetdisplay.String = [num2str(state.track.head.thresh*100) '% thresh'];
        
        ui.headoadjust.Value = state.track.head.offset;
        ui.headosetdisplay.String = [num2str(state.track.head.offset) 'px offset'];
        
        ui.headeadjust.Value = state.track.head.extent;
        ui.headesetdisplay.String = [num2str(state.track.head.extent) 'px extent'];
        
        ui.headnadjust.Value = state.track.head.npts;
        ui.headnsetdisplay.String = [num2str(state.track.head.npts) 'px tracked'];
        
        ui.headuadjust.Value = state.track.head.utheta;
        ui.headusetdisplay.String = [num2str(360-state.track.head.utheta) '° upper'];
        
        ui.headladjust.Value = state.track.head.ltheta;
        ui.headlsetdisplay.String = [num2str(360-state.track.head.ltheta) '° lower'];
        
        %abdomen
        ui.abdnormdropdown.Value = state.track.abd.norm;
        ui.overlayabdcheck.Value = state.track.abd.show.thresh;
        
        ui.abdtadjust.Value = state.track.abd.thresh;
        ui.abdtsetdisplay.String = [num2str(state.track.abd.thresh*100) '% thresh'];
        
        ui.abdoadjust.Value = state.track.abd.offset;
        ui.abdosetdisplay.String = [num2str(state.track.abd.offset) 'px offset'];
        
        ui.abdeadjust.Value = state.track.abd.extent;
        ui.abdesetdisplay.String = [num2str(state.track.abd.extent) 'px extent'];
        
        ui.abdnadjust.Value = state.track.abd.npts;
        ui.abdnsetdisplay.String = [num2str(state.track.abd.npts) 'px tracked'];
        
        ui.abduadjust.Value = state.track.abd.utheta;
        ui.abdusetdisplay.String = [num2str(360-state.track.abd.utheta) '° upper'];
        
        ui.abdladjust.Value = state.track.abd.ltheta;
        ui.abdlsetdisplay.String = [num2str(360-state.track.abd.ltheta) '° lower'];
        
        %legs
        ui.legnormdropdown.Value = state.track.leg.norm;
        ui.overlaylegcheck.Value = state.track.leg.show.thresh;
        ui.clearlegbordercheck.Value = state.track.leg.clearborder;
        
        ui.legtiadjust.Value = state.track.leg.threshint;
        ui.legtisetdisplay.String = [num2str(state.track.leg.threshint*100) '% threshInt'];
        
        ui.legtsadjust.Value = state.track.leg.threshsize;
        ui.legtssetdisplay.String = [num2str(state.track.leg.threshsize) 'px threshSz'];
        
        ui.legapadjust.Value = state.track.leg.ap/100;
        ui.legapsetdisplay.String = [num2str(100-state.track.leg.ap) '% AP'];
        
        ui.legoadjust.Value = state.track.leg.offset;
        ui.legosetdisplay.String = [num2str(state.track.leg.offset) 'px offset'];
        
        ui.legeadjust.Value = state.track.leg.extent;
        ui.legesetdisplay.String = [num2str(state.track.leg.extent) 'px extent'];
        
        span = state.track.leg.utheta-state.track.leg.ltheta;
        ui.legspnadjust.Value = span;
        ui.legspnsetdisplay.String = [num2str(span) '° span'];
    end

    %% plotting control callbacks
    function zoomctrl(b,~)
        switch b.String
            case 'Z+'
                b.String = 'Z-';
            case 'Z-'
                b.String = 'Z+';
        end
        if strcmp(vtimer.Running,'off')
            plotdata();
        end
    end

    function ixtctrl(b,~)
        switch b.String
            case 'ix'
                b.String = 't';
            case 't'
                b.String = 'ix';
        end
        if strcmp(vtimer.Running,'off')
            plotdata();
        end
    end

    %function called when tracking parameters change
    function updatetracking()
        if ~isempty(state.track.head.root)
            hr = state.track.head.root;
            ui.headrootxadjust.Enable = 'on';
            ui.headrootxadjust.Value = hr(1);
            ui.headrootyadjust.Enable = 'on';
            ui.headrootyadjust.Value = state.vid.height-hr(2);
            ui.headsetdisplay.String = ['x=' num2str(hr(1)) ' y=' num2str(hr(2))];            
        end
        if ~isempty(state.track.abd.root)
            ar = state.track.abd.root;
            ui.abdrootxadjust.Enable = 'on';
            ui.abdrootxadjust.Value = ar(1);
            ui.abdrootyadjust.Enable = 'on';
            ui.abdrootyadjust.Value = state.vid.height-ar(2);
            ui.abdsetdisplay.String = ['x=' num2str(ar(1)) ' y=' num2str(ar(2))];            
        end
        if ~isempty(state.track.abd.root) && ~isempty(state.track.head.root)
            ui.trackpanel.Visible = 'on';
            if ~isempty(findobj('Parent',ui.tabs))
                ui.tabs.Visible = 'on';
            else
                ui.tabs.Visible = 'off';
            end           
            calcbodypoints;
            makewingmask;
            makeheadmask;
            makeabdmask;
            makelegmask;
        end
        
        if strcmp(vtimer.Running,'off')
            processframe();
            showframe();
            plotdata();
        end
    end
    %calculate body control points
    function calcbodypoints()
        ar = double(state.track.abd.root);
        hr = double(state.track.head.root);
        state.track.orientation = atan2d(ar(2)-hr(2),ar(1)-hr(1))-90;
        d = pdist2(hr,ar,'euclidean'); 
        
        %get wingroots
        ap = round(state.track.wing.ap*d*.01);
        ml = round(state.track.wing.ml*d*.01);
        
        wc(1) = ar(1)+(ap(1))*sind(state.track.orientation);
        wc(2) = ar(2)-(ap(1))*cosd(state.track.orientation);
        wr(1,1) = wc(1)+(ml(1))*sind(state.track.orientation-90);
        wr(1,2) = wc(2)-(ml(1))*cosd(state.track.orientation-90);
        
        wc(1) = ar(1)+(ap(2))*sind(state.track.orientation);
        wc(2) = ar(2)-(ap(2))*cosd(state.track.orientation);
        wr(2,1) = wc(1)+(ml(2))*sind(state.track.orientation+90);
        wr(2,2) = wc(2)-(ml(2))*cosd(state.track.orientation+90);
        state.track.wing.root = wr; 
        
        %get proleg roots
        ap = round(state.track.leg.ap*d*.01);
        ml = round(state.track.leg.offset);
        
        wc(1) = ar(1)+(ap)*sind(state.track.orientation);
        wc(2) = ar(2)-(ap)*cosd(state.track.orientation);
        lr(1,1) = wc(1)+(ml)*sind(state.track.orientation-90);
        lr(1,2) = wc(2)-(ml)*cosd(state.track.orientation-90);
        
        wc(1) = ar(1)+(ap)*sind(state.track.orientation);
        wc(2) = ar(2)-(ap)*cosd(state.track.orientation);
        lr(2,1) = wc(1)+(ml)*sind(state.track.orientation+90);
        lr(2,2) = wc(2)-(ml)*cosd(state.track.orientation+90);
        state.track.leg.root = lr; 
    end
    %wing tracking function
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
        if size(img,3)>1
            img = rgb2gray(img);
        end
       if norm == 2 % normalize tracking ROI only
            img = imadjust(img,stretchlim(img(mask)));
       elseif norm == 3 %normalize whole image
           img = imadjust(img);
       end
        if thresh>0
            bw  = imbinarize(img,thresh)&mask;
        else
            bw = imbinarize(img,graythresh(img(mask)))&mask;
        end
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
    %head/abd tracking function
    function [angle,pts,bw] = tracktip(img,mask,root,thresh,norm,npts,mode,arg)
        if nargin<7 || isempty(mode)
            mode = 1;
        end
        if nargin<8 || isempty(arg)
            switch mode
                case 1 % average of distribution tails
                    arg = [10 90]; %upper and lower 10 percentiles default
                case 2 % average of k-means cluster centroids
                    arg = 2; %2 clusters default
            end
        end
        root = double(root);
        if size(img,3)>1
            img = rgb2gray(img);
        end
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
    %leg tracking function
    function [angle,tip,extrema,bw] = tracklegs(img,mask,borderlin,roots,threshint,threshsize,norm)
        roots = double(roots);
        if size(img,3)>1
            img = rgb2gray(img);
        end
       if norm == 2 % normalize tracking ROI only
            img = imadjust(img,stretchlim(img(mask)));
       elseif norm == 3 %normalize whole image
           img = imadjust(img);
       end
        bw  = imbinarize(img(:,:,1),threshint)&mask;
        p = regionprops(bw,'Area','Orientation','Extrema');     
        

            angle = nan(1,2); %null tracking if the ROI is blacked out
            tip = nan(2,2);
            extrema = nan(2,16);
            if  isempty(p) | bw == mask
                return %whiteout
            end
            if ~any(bw(:)~=0)
                return %blackout
            end
            
            areas = [p.Area];
            keepix = areas>threshsize;
            areas = areas(keepix);
            p = p(keepix);
            if isempty(p)
                return;
            end
           
            side = [];
            tips = [];
            if state.track.leg.clearborder
                border = [];
            else
                border = zeros(1,length(p));
            end
            for i = 1:length(p)
                extr = p(i).Extrema;
                leftdist = sqrt((extr(:,1)-roots(1,1)).^2 + (extr(:,2)-roots(1,2)).^2);
                rightdist = sqrt((extr(:,1)-roots(2,1)).^2 + (extr(:,2)-roots(2,2)).^2);
                [~,sd] = min([leftdist rightdist]');
                sd = mode(sd);
                side(end+1) = sd;
                if sd == 1
                    [~,tipix] = maxk(leftdist,2);
                else
                    [~,tipix] = maxk(rightdist,2);
                end
                tip = extr(tipix,:);
                tips = [tips;mean(tip)];
                
                if state.track.leg.clearborder
                    extr = round(extr);%make into idx
                    extr(extr<1) = 1;
                    extr(extr(:,1)>size(mask,2),1)=size(mask,2);
                    extr(extr(:,2)>size(mask,1),2)=size(mask,1);
                    extr = sub2ind(size(mask),extr(:,2),extr(:,1));
                    
                    inpol = ismember(extr,borderlin);
                    border(end+1)= sum(inpol)>5;
                end
            end
            lix = side==1&~border;
            rix = side==2&~border;
            leftp = p(lix);
            rightp = p(rix);
            leftip = tips(lix,:);
            rightip = tips(rix,:);
            if ~isempty(leftp)
                [~, maxix] = max(areas(lix));
                a = wrapTo360(leftp(maxix).Orientation);
                if a<180; a = a+180;end
                angle = a;
                tip = leftip(maxix,:);
                extr = leftp(maxix).Extrema;            
                extrema = reshape(extr',[1,16]);
            else
                angle = nan; %null tracking if the ROI is blacked out
                tip = nan(1,2);
                extrema = nan(1,16);
            end
            if ~isempty(rightp)
                [~, maxix] = max(areas(rix));
                a = wrapTo360(rightp(maxix).Orientation);
                if a<180; a = a+180;end
                angle = [angle a];
                tip = [tip; rightip(maxix,:)];
                extr = rightp(maxix).Extrema;            
                extrema = [extrema;reshape(extr',[1,16])];
            else
                angle = [angle nan];
                tip = [tip; nan(1,2)];
                extrema = [extrema;nan(1,16)];
            end
%         end
    end
    %make ROI function
    function [mask, poly] = make_arc_mask(centx,centy,r1,r2,theta1,theta2,w,h,majax,minax,shift)
        %assume a circle if no major/minor axes provided
        if nargin<11;shift = 0;end
        if nargin<10;minax=1;end
        if nargin<9;majax=1;end
        
        angle = linspace(theta1,theta2);
        
        x1 = majax*r1*cosd(angle-shift);
        x2 = majax*r2*cosd(angle-shift);
        
        y1 = minax*r1*sind(angle-shift);
        y2 = minax*r2*sind(angle-shift);
        
        %make and apply transformation matrix
        R  = [cosd(shift) -sind(shift); ...
            sind(shift)  cosd(shift)];
        rCoords = R*[x1 ; y1];
        x1 = rCoords(1,:);
        y1 = rCoords(2,:);
        rCoords = R*[x2 ; y2];
        x2 = rCoords(1,:);
        y2 = rCoords(2,:);

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
    %pick point in image
    function pt = pickpt(n)
        if nargin<1
            n = 1;
        end
        axes(vidax);
        h = get(0,'ScreenSize');
        h = h(4);
        mouse.mouseMove(vf.Position(1)+vf.Position(3)/2,...
            h-(vf.Position(2)+vf.Position(4)/2));
        pt = int16(ginput(n));
        pt = double(pt);
    end
    %overlay threshold onto image
    function rgb = overlaythresh(rgb,color,bw)
        rgb = imoverlay(rgb,bw,color./255);
    end
    %make colors
    function col = getcolors(ix)
        % declare color schemes
        i = 0; %have an index to manually iterate for easier copy/pasting
        
        %default scheme (Colors from ColorBrewer.org by Cynthia Brewer)
        i = i+1;
        colorschemes(i).head = [55 126 184];
        colorschemes(i).abd = [152 78 163];
        colorschemes(i).wingL = [77 175 74];
        colorschemes(i).wingR = [228 26 28];
        colorschemes(i).leg = [255 217 47];
        colorschemes(i).axis = [255 127 0];
        colorschemes(i).name = 'Default';
        
        %RGB scheme (After Kinefly by Steve Safarik)
        i = i+1;
        colorschemes(i).head = [0 255 255];
        colorschemes(i).abd = [255 0 255];
        colorschemes(i).wingL = [0 255 0];
        colorschemes(i).wingR = [255 0 0];
        colorschemes(i).leg = [255 255 0];
        colorschemes(i).axis = [0 0 255];
        colorschemes(i).name = 'RGB'; 
        
        i = i+1;
        colorschemes(i).head = 255-[55 126 184];
        colorschemes(i).abd = 255-[152 78 163];
        colorschemes(i).wingL = 255-[77 175 74];
        colorschemes(i).wingR = 255-[228 26 28];
        colorschemes(i).leg = 255-[255 217 47];
        colorschemes(i).axis = 255-[255 127 0];
        colorschemes(i).name = 'Default Inverted';
        
        col = colorschemes(ix);
    end
end