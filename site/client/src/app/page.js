"use client";
import React, { useEffect } from "react";
import { EvervaultCard } from "./components/ui/evervault-card";
import { LampDemo } from "./components/ui/lamp";
import { GoogleGeminiEffectDemo } from "./components/gemini";
import { useMotionValue } from "framer-motion";

function App() {
  // Create motion values individually
  const pathLength1 = useMotionValue(0);
  const pathLength2 = useMotionValue(0);
  const pathLength3 = useMotionValue(0);
  const pathLength4 = useMotionValue(0);
  const pathLength5 = useMotionValue(0);

  const pathLengths = [
    pathLength1,
    pathLength2,
    pathLength3,
    pathLength4,
    pathLength5,
  ];

  useEffect(() => {
    const handleScroll = () => {
      const scrollTop = window.scrollY || document.documentElement.scrollTop;
      pathLengths.forEach((motionValue) => {
        const incrementFactor = 0.1; // Adjust the increment factor as needed
        motionValue.set(scrollTop * incrementFactor);
      });
    };

    window.addEventListener("scroll", handleScroll);

    return () => {
      window.removeEventListener("scroll", handleScroll);
    };
  }, [pathLengths]); // Include pathLengths in the dependency array

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-black">
      {/* Render the LampDemo component */}
      <LampDemo />

      {/* Render the GoogleGeminiEffect component */}
      <GoogleGeminiEffectDemo />

      {/* Horizontally align and center the EvervaultCard components */}
      <div className="flex justify-center mt-10 space-x-14">
        {/* Render three EvervaultCard components */}
        {/* Adjusted size using Tailwind CSS utility classes */}
        <EvervaultCard text="zETH" className="bg-black w-64 h-64" />
        <EvervaultCard text="zBTC" className="bg-black w-64 h-64" />
        <EvervaultCard text="zTRX" className="bg-black w-64 h-64" />
      </div>
    </div>
  );
}

export default App;
