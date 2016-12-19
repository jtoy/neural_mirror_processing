//every 30 seconds,take a picture
// we render the images into a random style/dream, then we cycle through those images. 
//save a list of images in data/processed, then have our code randomly grab and render it
import processing.video.*;
import java.util.Calendar;
import http.requests.*;
import java.nio.file.Paths;
import java.nio.file.Path;
import java.util.Arrays;
import java.nio.file.Files;
import java.util.Random;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.entity.mime.MultipartEntity;
import org.apache.http.entity.mime.content.FileBody;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.entity.mime.content.StringBody;
import org.apache.http.message.BasicNameValuePair;
import java.io.FileOutputStream;
import java.util.Map;
import java.lang.*;
PImage cam_image;
FileBody camFileBody;
HttpResponse response;
Capture cam;
String path;
PImage target_image;
PImage source_image;
PImage jitter_image;
PImage m;
float rot = 360.0;
PGraphics pgTaiji;
PImage piBuffer;
PImage transition_image;
int our_height = 1080;
int our_width = 1920;
int processed = 0;
int switch_count = 0;
int threads_processing = 0;
int lastTime = 0;
int direction = 0;
float lerp_rate = 0;
String[] dream_ids = {"pE4A9yk0","7ZxJpMk9","DkMle5Eg"};
String[] style_ids = {"LnL71DkK","9kgYo1Zp","Bka9oBkM","2kRl49ZW","MZJNYmZY","LnL7oLkK","8k8aLmnM","yE72lBZm","VEqz4xkx","7E9r2WkR","MZJN75ZY"};
String url = "http://convert.somatic.io/api/v1.2/post-query";
String[] model_ids = concat(dream_ids,style_ids);
String cam_path;
int first_step = 0;
File processed_dir;
File cam_dir;
 

PGraphics rotatingTaiji(int a,float xstep,float ystep) {
  PGraphics taiji = createGraphics(width, height);
  taiji.beginDraw();
  taiji.translate((width-height)/2, 0);
  taiji.background(230,0);
  taiji.fill(255);
  taiji.arc(xstep,ystep,a,a,PI/2,PI*3/2);
  //draw right black arc
  taiji.fill(0);
  taiji.arc(xstep,ystep,a,a,-PI/2,PI/2);
  taiji.noStroke();
  //draw down big arc
  taiji.arc(a/2,a*3/4,a/2,a/2,PI/2,PI*3/2);
  //draw up big arc
  taiji.fill(255);
  taiji.arc(a/2,a/4,a/2,a/2,-PI/2,PI/2);
  //draw down small arc
  taiji.ellipse(a/2,a*3/4,a/10,a/10);
  //draw up small arc
  taiji.fill(0);
  taiji.ellipse(a/2,a/4,a/10,a/10);
  taiji.endDraw();
  return taiji;
}
class Somatic implements Runnable {
  private Thread t;
  PImage image;
  String image_path;
  int retry_count = 0;
  public Somatic(String img_path) {
    image_path = img_path;
  }
  public void start () {
    t = new Thread (this, image_path);
    t.start ();
  }
  public void run(){
    println("RUN");
      int rnd = new Random().nextInt(model_ids.length);
      String model_id = model_ids[rnd];
      String field_name = null;
      if(Arrays.asList(dream_ids).contains(model_id)){
        field_name = "--image";
      }else{
        field_name = "--input";
      }
      println("get_model_id:"+model_id);
      DefaultHttpClient client = new DefaultHttpClient();
      HttpPost post = new HttpPost(url);

      try{

      MultipartEntity entity = new MultipartEntity();
      BasicNameValuePair nvp = new BasicNameValuePair("api_key",System.getenv("SOMATIC_API_KEY"));

      entity.addPart(nvp.getName(), new StringBody(nvp.getValue()));
      File cam_file = new File(image_path);
      println(cam_file.length());
      entity.addPart(field_name, new FileBody(new File(image_path)));
      BasicNameValuePair nvp2 = new BasicNameValuePair("id",model_id);
      entity.addPart(nvp2.getName(), new StringBody(nvp2.getValue()));
      post.setEntity(entity);
      HttpResponse response = client.execute(post);
      Calendar now = Calendar.getInstance();
      String processed_path = path+"/processed/"+String.format("%1$ty%1$tm%1$td_%1$tH%1$tM%1$tS", now)+"_"+model_id+".png";
      InputStream instream = response.getEntity().getContent();
      FileOutputStream output = new FileOutputStream(processed_path);
      int bufferSize = 1024;
      byte[] buffer = new byte[bufferSize];
      int len = 0;
      while ((len = instream.read(buffer)) != -1) {
          output.write(buffer, 0, len);
      }
      output.close();

      PImage tmp = loadImage(processed_path);
      if(tmp.width != -1 && tmp.height != -1){
        println("style fine");
        image = tmp.copy();
        //if(target_image == null){
        if(tmp.height != height || tmp.width !=  width){
          tmp.resize(width,height);
        }
        target_image= tmp.copy();
        //}
      }else{
        println("style not fine");
      }
      processed += 1;
      threads_processing -= 1;
      println("processed");
      }catch (Exception e){
        //retry_count += 1 ;
        println("shit");
        e.printStackTrace();
      }
    }
}

void get_image(){
  //if(cam.available()) {
    cam.read();
  
    Calendar now = Calendar.getInstance();
    cam_path = path+"/cams/"+String.format("%1$ty%1$tm%1$td_%1$tH%1$tM%1$tS", now)+".jpg";
    cam.save(cam_path);
    Somatic transformer = new Somatic(cam_path);
    transformer.start();
  //}else{

  //}
}

void setup() {
  path = dataPath("");
  processed_dir = new File(path+"/processed/");
  processed_dir.mkdirs();
  cam_dir = new File(path+"/cams/");
  cam_dir.mkdirs();
  //size(1080,1080,P2D);
  fullScreen(P2D);
  println("key:"+System.getenv("SOMATIC_API_KEY"));
  cam = new Capture(this, 1920,1080);
  //cam = new Capture(this, 1280,720);
  //cam = new Capture(this, 1280,720, "Live! Cam Sync HD VF0770");
  cam.start();
   if(cam.available()) {
    cam.read();
   }
  transition_image = createImage(width,height, RGB);
  cam_image = cam;
  source_image = cam.copy();
  if(source_image.height !=height || source_image.width !=width){
    source_image.resize(width,height);
  }
  smooth();
  pgTaiji = rotatingTaiji(height, height/2, height/2);
  piBuffer = pgTaiji.get();
  m = pgTaiji.get();
}
void draw() {
  background(225);
  if(cam.available()) {
    cam.read();
  }
  if( millis() >= 5000 && target_image == null  ){
    image(cam,0,0);
    source_image = cam.copy();
  if(source_image.height !=height || source_image.width !=width){
    source_image.resize(width,height);
  }
    cam_image = cam;
    if(first_step == 0){
      get_image();
      first_step = 1;

    }
  }else if(millis()  < 5000  ){
    println("only firset 5");
    image(cam,0,0);

  }else if( millis() - lastTime >= 30000){
  //}else if( millis() - lastTime >= 120000){
    lastTime = millis();
    println("1 minute passed");
    get_image();

  }else if (source_image != null && target_image != null){

  pgTaiji.pushMatrix();
  pgTaiji.imageMode(CENTER);
  pgTaiji.beginDraw();
  pgTaiji.translate(pgTaiji.width/2, pgTaiji.height/2);
  pgTaiji.rotate(radians(rot));
  pgTaiji.image(piBuffer, 0, 0);
  pgTaiji.endDraw();
  pgTaiji.popMatrix();

  rot+=1;
  if (rot < 0) rot = 360;

  m = pgTaiji.get();
  image(m,0,0);
    target_image.loadPixels();
    source_image.loadPixels();
    transition_image.updatePixels();
    if(target_image.height != height || target_image.width !=  width){
      target_image.resize(width,height);
    }

    if(source_image.height !=height || source_image.width !=width){
      source_image.resize(width,height);
    }
    if(transition_image.height != height || transition_image.width != width){
      transition_image.resize(width,height);
    }



  //  image(jitter_image, 0, 0, 200, 200);

  loadPixels();
  for (int y = 0; y < target_image.height; y++) {
    for (int x = 0; x < target_image.width; x++) {
      int loc = x + y*target_image.width;
      if (lerp_rate<=0.5) {
        color new_color = lerpColor(source_image.pixels[loc], m.pixels[loc], lerp_rate*2);
        transition_image.pixels[loc] = new_color;
      }
      else {
        color new_color = lerpColor(target_image.pixels[loc], m.pixels[loc], 2-2*lerp_rate);
        transition_image.pixels[loc] = new_color;
      }
    }
  }
  transition_image.updatePixels();
  lerp_rate += 0.01;
  lerp_rate = constrain(lerp_rate, 0,1);
  float jitter;
  if (lerp_rate < 0.5) {
    jitter = map(lerp_rate, 0, 0.5, 0, 1);
  } else {
    jitter = map(lerp_rate, 0.5, 1, 1, 0);
  }


  image(transition_image, 0,0);
//  text("Jitter: " + jitter, 10,10);
  if (jitter== 1 || jitter == 0){
    lerp_rate = 0;
    cam.read();
    PImage next_image = null;
    while(next_image == null){
      println("XXXXXXXXXXXX");
      File[] listOfFiles = processed_dir.listFiles();
      int file_count = listOfFiles.length;
      Random random = new Random();
      int index = random.nextInt(file_count);
      //println(listOfFiles[index]);
      //println("ASDSD");
      String filePath = listOfFiles[index].toString();
      println(filePath);
      next_image = loadImage(filePath);
    }
    println("end while");

      source_image = target_image.copy();
      target_image = next_image.copy(); //change this to read from data/processed and load a random image

  }

  }

}
