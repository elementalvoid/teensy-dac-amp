#include <Arduino.h>

#include <Audio.h>
#include <PrintEx.h>

#define DEBUG true
#define VOLUME_PIN 15
#define AUDIO_MEMORY 20
#define MAX_VOLUME 0.8
// Spectrum params
#define SPECTRUM_DECAY 2
#define SPECTRUM_MIN_HEIGHT 1.0
#define SPECTRUM_MAX_HEIGHT 20.0

StreamEx serial = Serial;

elapsedMillis volumeMillis;
elapsedMillis spectrumMillis;

// GUItool: begin automatically generated code
AudioInputUSB            usbIn;           //xy=292,232
AudioMixer4              fftMixer;         //xy=512,320
AudioOutputI2S           i2sOut;           //xy=547,180
AudioAnalyzeFFT1024      fftData;       //xy=712,382
AudioConnection          patchCord1(usbIn, 0, fftMixer, 0);
AudioConnection          patchCord2(usbIn, 0, i2sOut, 0);
AudioConnection          patchCord3(usbIn, 1, fftMixer, 1);
AudioConnection          patchCord4(usbIn, 1, i2sOut, 1);
AudioConnection          patchCord5(fftMixer, fftData);
AudioControlSGTL5000     audioShield;       //xy=489,480
// GUItool: end automatically generated code

// float version of `map`: https://www.arduino.cc/en/Reference/Map
float fmap(float x, float in_min, float in_max, float out_min, float out_max)
{
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

void setup() {
  Serial.begin(9600); // note that USB is always 12 Mbit/sec

  AudioMemory(AUDIO_MEMORY); // set based on debug printing max used plus some buffer
  audioShield.enable();

  // DAC settings
  audioShield.audioPostProcessorEnable();
  //TODO: Put this on a toggle switch
  audioShield.enhanceBassEnable();
}

void processFFTData() {
  // This array holds the on-screen levels.  When the signal drops quickly,
  // these are used to lower the on-screen level 1 bar per update, which
  // looks more pleasing to corresponds to human sound perception.
  static float shown[16];

  // read the 512 FFT frequencies into 16 levels music is heard in octaves, but the FFT data
  // is linear, so for the higher octaves, read many FFT bins together.
  // See this conversation to change this to more or less than 16 log-scaled bands:
  // https://forum.pjrc.com/threads/32677-Is-there-a-logarithmic-function-for-FFT-bin-selection-for-any-given-of-bands
  const uint16_t fftOctTab1024[] = {
  0,0,
  1,1,
  2,3,
  4,6,
  7,10,
  11,15,
  16,22,
  23,32,
  33,46,
  47,66,
  67,93,
  94,131,
  132,184,
  185,257,
  258,359,
  360,511
  };

  if (fftData.available()) {
    for (int i = 0; i < 15; i++) {
      float level = fftData.read(fftOctTab1024[i * 2], fftOctTab1024[i * 2 + 1]);
      float val = 0;
      if (level > 0) {
        // provide a positive number with absolute scale:
        // 150 plus the (negative) magnitude to dB conversion (log10f of 0<=x<=1 is negative)
        val = 150 + (20 * log10f(level));
        if (val < 0) {
          // safety net, probably not needed...
          val = 0;
        }
      }
      float oldval = shown[i];
      val = fmap(val, 0.0, 150.0, SPECTRUM_MIN_HEIGHT, SPECTRUM_MAX_HEIGHT);

      if (val < oldval - SPECTRUM_DECAY ) {
        val = oldval - SPECTRUM_DECAY;
      }
      if (val < SPECTRUM_MIN_HEIGHT) {
        val = SPECTRUM_MIN_HEIGHT;
      } else if (val > SPECTRUM_MAX_HEIGHT) {
        val = SPECTRUM_MAX_HEIGHT;
      }
      shown[i] = val;
#ifdef DEBUG
      serial.printf("%02d ", (int)val);
#endif
    }
#ifdef DEBUG
    serial.concat(" cpu: ")
    .concat(AudioProcessorUsage())
    .concat(",")
    .concat(AudioProcessorUsageMax())
    .concat(" mem: ")
    .concat(AudioMemoryUsage())
    .concat(",")
    .concatln(AudioMemoryUsageMax());
#endif
  }
}

void handleVolumeKnob() {
  static float lastVol = 0.5;
  float vol = analogRead(VOLUME_PIN);
  vol = fmap((float)vol, 0.0, 1023.0, 0.0, MAX_VOLUME);
  if (lastVol != vol && abs(lastVol - vol) > 0.005)
  {
    audioShield.volume(vol);
    lastVol = vol;
  }
}

void loop() {
  if (volumeMillis > 10) {
    handleVolumeKnob();
    volumeMillis = 0;
  }

  if (spectrumMillis > 5) {
    processFFTData();
    spectrumMillis = spectrumMillis - 5;
  }

  // TODO: make PC's volume setting control the SGTL5000 volume...
}

extern "C" int main(void)
{
  // Arduino's main() function just calls setup() and loop()....
  setup();
  while (1) {
    loop();
    yield();
  }
}

