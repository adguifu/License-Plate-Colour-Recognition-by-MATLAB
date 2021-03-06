%% 初始化Initialize
clear;
close all;
matlabpool open;%打开cpu所有核心 Open all cpu cores
corenum = 16;%我这个服务器是16核心的 My computer has 16 cores
inputpath = 'C:\卡口数据（总）\卡口数据2017.4.17\';%图片输入路径 Input file location
outputpath = 'C:\卡口数据（总）\yellow4\';%图片输出路径 Output file location
Files = dir(fullfile(inputpath,'*.jpg'));%载入每个图片路径信息 Load input file location
LengthFiles = length(Files);%计算文件夹内的图片张数 Count images

%% 并行计算配置 Config parallel computation
for i = 1:corenum:LengthFiles;%16个图像一批，同时处理 Processing 16 images in a batch
    Scolor = Composite();%创建Composite对象 Create Composite object
    for j = 1:corenum
        Scolor{j} = imread(strcat(inputpath,Files(i+j-1).name));%为Composite对象进行初始化赋值，即为每个核心分配待处理的图片 Allocate images to each core
        fprintf('Processing:No.%d  %s\n',i+j-1,Files(i+j-1).name);%输出当前状态信息 Print state information
    end
    
    %% 每个对象都使用的图像处理方法 Image progress code
    spmd
        %Step1 图像截取与黄色区域增强 Cut the image and intensificate the yellow part
        Scolor = Scolor(300:end-300,300:end-300,:);%截取图像的中间部分 Reserve the center of images
        Sgray=imsubtract(Scolor(:,:,1),Scolor(:,:,3));%图通道相减 Channel subtract
        %将彩色图像转换为黑白并显示 RGB to Gray
        Sgray_gray = rgb2gray(Scolor);%rgb2gray转换成灰度图
%         figure,imshow(Sgray),title('原始黑白图像');
        %Step2 图像预处理   对Sgray 原始黑白图像进行开操作得到图像背景 Open operation on Grey image
        s=strel('disk',17);%strei函数 Strei function
        Bgray=imopen(Sgray,s);%图像开运算 Open operation
%         figure,imshow(Bgray);title('背景图像');%输出背景图像 Output background images
        Egray=imsubtract(Sgray,Bgray);%两幅图相减，用原始图像与背景图像作减法，增强图像 Image subtract
%         figure,imshow(Egray);title('增强黑白图像');%输出黑白图像 Output grey images
        
        %Step3 取得最佳阈值，将图像二值化
        fmax1=double(max(max(Egray)));%egray的最大值并输出双精度型
        fmin1=double(min(min(Egray)));%egray的最小值并输出双精度型
        level=(fmax1-(fmax1-fmin1)/3)/255;%获得最佳阈值 Get best threshold
        bw22=im2bw(Egray,level);%转换图像为二进制图像
        bw2=double(bw22);
        
        %Step4 对得到二值图像作开闭操作进行滤波  Open and close operations to filter waves
%         figure,imshow(bw2);title('图像二值化');%得到二值图像
        grd = edge(bw2,'canny');%用canny算子识别强度图像中的边界 Use 'canny' operator to recognize the edge of images
%         figure,imshow(grd);title('图像边缘提取');%输出图像边缘
        bg1=imclose(grd,strel('rectangle',[5,19]));%取矩形框的闭运算 Close operation with rectangle shape
%         figure,imshow(bg1);title('图像闭运算[5,19]');%输出闭运算的图像
        se = strel('disk',3);
        grd = imdilate(bg1,se);
        bg1=imclose(grd,strel('rectangle',[5,19]));%取矩形框的闭运算
%         figure,imshow(bg1);title('图像闭运算[5,19]');%输出闭运算的图像
        bg3=imopen(bg1,strel('rectangle',[5,19]));%取矩形框的开运算
%         figure,imshow(bg3);title('图像开运算[5,19]');%输出开运算的图像
        bg2=imopen(bg3,strel('rectangle',[19,1]));%取矩形框的开运算
%         figure,imshow(bg2);title('图像开运算[19,1]');%输出开运算的图像
        
        %Step5 对二值图像进行区域提取，并计算区域特征参数。进行区域特征参数比较，提取车牌区域
        [L,num] = bwlabel(bg2,8);%标注二进制图像中已连接的部分  Callout the connected part of a binary image
        Feastats = regionprops(L,'basic');%计算图像区域的特征尺寸 Calculate the feature size of the image area
        Area=[Feastats.Area];%区域面积 Area measure
        if ~isempty(Area)%区域是否为空，即没有黄色区域 Is area empty or not
            BoundingBox=[Feastats.BoundingBox];%[x y width height]车牌的框架大小 The size of licence plate
            x = floor(BoundingBox(1));%向下取整，剪切区域时，坐标点不允许有小数 Round down,coordinate points are not allowed in decimal when shear zone
            y = floor(BoundingBox(2));
            width = BoundingBox(3);
            height = BoundingBox(4);
            if x>0 && x < 1800 && y > 0 && y < 1100
                imgcut= Scolor(y:(y+height),x:(x+width),:);%剪切出黄色车牌区域 Cut out the yellow plate area
                % imshow(imgcut);
                imgfinal = imresize(imgcut,[1,1]);%计算颜色均值  Calculate color mean
                signa = imgfinal(:,:,1);%通道红 Red channel
                signb = imgfinal(:,:,2);%通道绿 Green channel
                signc = imgfinal(:,:,3);%通道蓝 Blue channel
                if signa - signc > 80 && signb -signc > 70 && signc < 70 %大致符合黄色 Set the num to recognize colors
                    copyfile(strcat(inputpath,Files(i+labindex-1).name), strcat(outputpath,Files(i+labindex-1).name));%将符合要求的图片复制到另一个文件夹中 Copy selected images to output folder
                    fprintf('OK:No.%d %s\n\n',i+labindex-1,Files(i+labindex-1).name);%符合要求的图片信息 Selected images' information
                end
            end
        end
    end
end
%% 结束
clear ;
close all;
matlabpool close;%关闭计算核心 Close cores