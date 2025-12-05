 /* Serial I/O between Matlab and Arduino UNO via USB
  This code aloows communication between arduino and MATLAB.
  Arduino sends data from the joystick voltage.
  Thomas Watson
  07 March 24
*/

//left stick variables
const byte joystick_pin_x_left = A1; // initialize variable joystick_pin_x to pin A0.
const byte joystick_pin_y_left = A0; // initialize variable joystick_pin_y to pin A1.
const byte joystick_press_left = 2;
bool left_pressed;

const byte joystick_pin_x_right = A3; // initialize variable joystick_pin_x to pin A0.
const byte joystick_pin_y_right = A2; // initialize variable joystick_pin_y to pin A1.
const byte joystick_press_right = 4;
bool right_pressed;


int data_from_MATLAB; // initialize variable as an int for data from MATLAB.

int x_left; // initialize variable x as an int to be the voltage reading of the x-axis of the joystick.
int y_left; // initialize variable y as an int to be the voltage reading of the y-axis of the joystick.

int x_right; // initialize variable x as an int to be the voltage reading of the x-axis of the joystick.
int y_right; // initialize variable y as an int to be the voltage reading of the y-axis of the joystick.

int i = 1; // declare vairaible i = 1 as int for counter.

void setup()
{

  // The following checks: “did MATLAB send me anything?”
  Serial.begin(2000000); // initialize serial communication at 2000000 bits per second for communication between Arduino and MATLAB via the serial port.
                         // essentially the speed limit on the data highway - not how fast things are being sent
                         
  delay(500); // delay half a second for initialization.
  pinMode(joystick_pin_x_left, INPUT); // set pinMode as INPUT for joystick_pin.
  pinMode(joystick_pin_y_left, INPUT); // set pinMode as INPUT for joystick_pin.
  pinMode(joystick_press_left, INPUT_PULLUP); // set up pullup as INPUT for button press

  pinMode(joystick_pin_x_right, INPUT); // set pinMode as INPUT for joystick_pin.
  pinMode(joystick_pin_y_right, INPUT); // set pinMode as INPUT for joystick_pin.
  pinMode(joystick_press_right, INPUT_PULLUP); // set up pullup as INPUT for button press
}

void loop()
{
  if (Serial.available() > 2) // Arduino waits for serial data to become available from MATLAB.
  {

    data_from_MATLAB = Serial.parseInt(); // load first valid integer from MATLAB. This is where arduino get the "ok - send ur shit"

    x_left = analogRead(joystick_pin_x_left); // read x-axis voltage of joystick_pin_x.
    y_left = analogRead(joystick_pin_y_left); // read y-axis voltage of joystick_pin_y.
    left_pressed = (digitalRead(joystick_press_left) == LOW); // LOW means “pressed”

    x_right = analogRead(joystick_pin_x_right); // read x-axis voltage of joystick_pin_x.
    y_right = analogRead(joystick_pin_y_right); // read y-axis voltage of joystick_pin_y.
    right_pressed = (digitalRead(joystick_press_right) == LOW); // LOW means “pressed”
    
    Serial.print(String(String(i) + "," + String(x_left) + "," + String(y_left) + "," + String(left_pressed ? 1 : 0) + "," + String(x_right) + "," + String(y_right) + "," + String(right_pressed ? 1 : 0))); // send counter and some data from arduino as a comma delimited string to MATLAB.


    Serial.write(13); // "Carriage Return".
    Serial.write(10); // "Linefeed".
    Serial.flush(); // wait for serial string to finish sending to MATLAB.


    i += 1; // Use counter to check that data transmission is synchronized.


  }
} // loop back to beginning. Wait for serial data to become available from MATLAB.
