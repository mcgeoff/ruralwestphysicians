// For census tract
package com.cartogrammar.shp{
  
  import flash.display.DisplayObject;
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.geom.Rectangle;
  import flash.net.URLLoader;
  import flash.net.URLLoaderDataFormat;
  import flash.net.URLRequest;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;
  
  import org.vanrijkom.dbf.*;
  import org.vanrijkom.shp.*;
  
  /**
   * The ShpMap class represents a map drawn from a single shapefile.
   * This class currently supports basic point, polyline, and polygon shapefiles.
   * @author Andy Woodruff (http://www.cartogrammar.com/blog);
   * 
   */
  public class ShpMapCT extends Sprite{
    
    /**
     * The geographic (e.g. states or countries) features contained in the shapefile.
     */
    public var features : Array = new Array();
    
    public var attributeFields : Array;
    public var ctData : Dictionary;
    //public var changePopulation : Dictionary;
    
    /**
     * A Sprite on which features will be added. This exists so that it can be positioned correctly within the ShpMap.
     */
    private var map : Sprite = new Sprite();
    
    private var dataLoader : URLLoader = new URLLoader();
    private var shpLoaded : Boolean = false;
    
    // string variables per county for tooltip passing purposes.
    // gets passed to ShpMapObject through event handler, then from there to RuralWestPop
    
    private var state:String = "";
    private var county:String = "";
    private var tract:String = "";
    private var ct_number:String = "";
    
    private var primary_phys:String = "";
    private var other_phys:String = "";
    private var all_phys:String = "";
    private var population:String = "";
    
    private var border : Boolean = false;
    private var western:Boolean = false; // whether to only show 11 western states
    
    /**
     * Constructor
     * @param src A String giving the location of the source shapefile.
     * @param dbfSrc (optional) A string giving the location of the DBF file associated with the shapefile
     */
    public function ShpMapCT( src : String, dbfSrc : String = null, 
                            ctData : Dictionary = null)
    {
      
      addChild(map);
      this.ctData = ctData;
      //this.changePopulation = changePopulation;
      
      // load the shapefile
      
      dataLoader.dataFormat = URLLoaderDataFormat.BINARY;
      dataLoader.load( new URLRequest(src) );
      dataLoader.addEventListener( Event.COMPLETE, onShapefile );
      
      if ( dbfSrc != null ) {
        var dbfLoader : URLLoader = new URLLoader();
        dbfLoader.dataFormat = URLLoaderDataFormat.BINARY;
        dbfLoader.load( new URLRequest(dbfSrc) );
        dbfLoader.addEventListener( Event.COMPLETE, onDBF );
      }
    }
    
    private function onShapefile( event:Event ) : void
    {
      
      // use the ShpTools class to parse the shapefile into an array of records
      var records : Array = ShpTools.readRecords(event.target.data).records;
      
      // create a feature (point, polyline, or polygon) from each record
      for each( var record : ShpRecord in records ){
        var feature : ShpFeature = createFeature(record);
        if ( feature != null ) features.push( feature );
      }
      
      shpLoaded = true;
      
      // draw the features
      drawMap();
      
      // to signal the completion of map loading/drawing
      dispatchEvent(new Event("map loaded",true));
    }
    
    /**
     * Creates the appropriate type of feature for a record.
     * @param record The source record.
     * @return A point, polyline, or polygon feature.
     * 
     */
    private function createFeature( record : ShpRecord ) : ShpFeature
    {
      var feature : ShpFeature;
      switch( record.shapeType ) {
        
        case ShpType.SHAPE_POINT:
        feature = new PointFeature(record);
        break;
        
        case ShpType.SHAPE_POLYLINE:
        feature = new PolylineFeature(record);
        break;
        
        case ShpType.SHAPE_POLYGON:
        feature = new PolygonFeature(record);
        break;
        
      }
      
      // other shape types will return null
      return feature;
    }
    
    // Event handler for DBF load.
    private function onDBF( event:Event ) : void
    {
      // Wait to create attributes until the shapefile is loaded.
      if (shpLoaded){
        createAttributes(event.target.data);
      } else {
        dataLoader.addEventListener( Event.COMPLETE, function(e:Event):void{ createAttributes(event.target.data); } );
      }
    }
    
    private function createAttributes( dbf : ByteArray ) : void
    {
      var dbfHeader : DbfHeader = new DbfHeader(dbf);
      
      // Checking if the DBF has the same number of records as the shapefile is a basic test of whether the two files match.
      if (dbfHeader.recordCount != features.length) {
        throw new Error("Shapefile/DBF record count mismatch. Attributes were not loaded.");
        return;
      }
      
      // Populate attribute field names array.
      attributeFields = new Array();
      for each ( var field : DbfField in dbfHeader.fields ) {
        attributeFields.push( field.name );
      }
      
      for ( var i : int = 0; i < features.length; i++ ) {
        features[i].values = DbfTools.getRecord(dbf,dbfHeader,i).values;
        features[i].addEventListener(MouseEvent.MOUSE_OVER,  displayCountyInfo);
        features[i].addEventListener(MouseEvent.ROLL_OUT, removeCountyInfo);
      }
      
      //TODO: now use hard coded value...
      updateMapColor("primary");
      
      dispatchEvent(new Event("attributes loaded",true));
      
    }
     
    public function updateMapColor(showMode:String):void {
    	
      // Assign attribute dictionaries to features.
      for ( var i : int = 0; i < features.length; i++ ) {
        if (!features[i].values) {
          //trace(i);
          continue;
        }
        
        var this_state:String = trim(features[i].values["STATE"]);
        var this_county:String = trim(features[i].values["COUNTY"]);
        var this_tract:String = trim(features[i].values["TRACT"]);
        this_tract = this_tract.substring(0, 4);
        var this_ct_num:String = this_state + this_county + this_tract;
        
        features[i].draw(0xbbbbbb, 0x444444, 0);
        /*
        //fips = trim(features[i].values["STATE"]);
        if (showMode == "none") {
          features[i].draw(0xbbbbbb, 0x444444, 0);
        } else if (showMode == "percapita_physicians") {
          if (this_ct_num.length >0 && ctData.hasOwnProperty(this_ct_num)) {
            //var value:Number = censusData[fips].total;
			trace("$updateMapColor$");
			var value:Number = 10; //ctData[this_ct_num].numPhys / ctData[fips].numPop;
			//trace(value);
			
			var state_name:String = features[i].values["STATE"];
			trace(state_name);
			
            if (value >= 0.01) {
              var color:uint = 0xFF4E37;  
            } else if (value >= 0.003) {
              color = 0xFF8878;  
            } else if (value >= 0.001) {
              color = 0xFFAE9A;  
            } else if (value >= 0.0005) {
              color = 0xFFDBC9;  
            } else if (value >= 0.0) {
              color = 0xFFFAF7;  
            } else {
              color = 0x999999;
            }
          } else {
            color = 0x999999;
          }
          if(western){    //WESTERN ONLY
          
            if(isWestern(state_name)){  // IS WESTERN STATE
              if(border)
                features[i].draw(0x444444, color);
              else
                features[i].draw(color, color);
            }
            else{    // NOT WESTERN STATE
              if(border)
                features[i].draw(0x999999, 0x999999);
              else
                features[i].draw(0x999999, 0x999999);
            } 
          }
          else{    // NOT WESTERN ONLY
            if(border)
              features[i].draw(0x444444, color);
            else
              features[i].draw(color, color);
          }

        } else if (showMode == "debug") {
          // put debug code here
          features[i].draw(); 
        } else {
          features[i].draw();
        }
        */
      }
    }
    
    private function isWestern(state_name:String):Boolean {
          
      return false;
    }
    
    private function displayCountyInfo(event:MouseEvent):void {
      
      state = trim(event.currentTarget.values["STATE"]);
      county = trim(event.currentTarget.values["COUNTY"]);
      tract = trim(event.currentTarget.values["TRACT"]);
      tract = tract.substr(0, 4);
      ct_number = state+county+tract;
      
    }
    
    private function removeCountyInfo(event:MouseEvent):void {
      state = ""; 
      county = "";
      tract = "";
      ct_number = "";
      primary_phys = "";
      other_phys = "";
      all_phys = "";
      dispatchEvent(new Event(Event.CHANGE));
    }
    
    public function getAllPhysicians():String{
      return all_phys;
    }
    
    public function getOtherPhysicians():String{
      return other_phys;
    }
    
    public function getPrimaryPhysicians():String{
      return primary_phys;
    }
    
    public function getState():String{
      return state;
    }
    public function getTract():String{
      return tract;
    }
    public function getCounty():String{
      return county;
    }
    public function getPopulation():String{
      return population;
    }
    
    
    /**
     * Retrieves a feature from the shapefile based on a specified attribute name and value.
     * This is meant for searching unique identifiers. If the field being searched has non-unique 
     * values, this method will only return the first encountered feature with a matching <code>value</code>.
     * @param key The attribute field name.
     * @param value  The attribute value.
     * @return The feature with the value <code>value</code> for the specified <code>key</code>, or <code>null</null> if no match is found or the <code>key</code> is invalid.
     * 
     */
    public function getFeatureByAttribute( key : String, value : * ) : ShpFeature
    {
      if ( attributeFields.indexOf( key ) == -1 ) return null;  // Fail if there is no such attribute name.
      for each ( var feature : ShpFeature in features ) {
        if ( feature.values[key] is String ) {
          var attribute : String = trim(feature.values[key]);
        } else {
          attribute = feature.values[key];
        }
        
        if ( attribute == value ) return feature;
        
      }
      return null;
    }
    
    // trims whitespace
    private function trim(str:String) : String {
      return str.replace(/^\s+|\s+$/g, '');
    }
    
    /**
     * Adds all the features to the display. 
     * 
     */
    private function drawMap() : void 
    {
      for each ( var feature : ShpFeature in features ) {
        map.addChild(feature);
      }
      
      /*  Features are all positioned according to their lat/long,
        meaning that x is somewhere from -180 to 180 and y is
        between -90 and 90. Here we get the actual bounds of all
        features and move the whole map so that its top left
        is at the normal (0,0) of Flash coordinate space. */
      var bounds : Rectangle = map.getBounds(this);
      map.x = -bounds.left;
      map.y = -bounds.top;
    }
    
    /**
     * Adds a given marker at a specified lat/long location.
     * A simple demonstration of how the everything is still geo-referenced.
     * @param lat The latitude at which to add the marker.
     * @param lon The longitude at which to add the marker.
     * @param marker The marker to add to the map.
     * 
     */
    public function addMarker( lat : Number, lon : Number, marker : DisplayObject ) :void
    {
      marker.x = lon;
      marker.y = -lat;  // remember that negative is UP in Flash but DOWN in latitude! hence the switch here and elsewhere
      map.addChild(marker);
    }
    
    public function getBorder( inbool:Boolean ):void{
      border = inbool;
    }
    
    public function getWestern( inbool:Boolean ):void{
      western = inbool;
    }
    
  }
  
}