session "Interaction_Trees" = "Shallow-Expressions-Z" +
  options [timeout = 600, document = pdf, document_output = "output"]
  theories
    ITrees
  document_files
    "root.tex"

session "ITree_Simulation" in "simulation" = "Interaction_Trees" +
  options [timeout = 600, document = false]
  theories
    ITree_Simulation

session "ITree_UTP" in "UTP" = "Interaction_Trees" +
  options [timeout = 600, document = false]
  theories
    ITree_UTP
    ITree_VCG

session "ITree_RoboChart" in "RoboChart" = "ITree_UTP" +
  options [timeout = 600, document = pdf, document_output = "output"]
  theories
    ITree_RoboChart
  document_files
    "root.tex"

session "RoboChart_basic" in "RoboChart/examples/RoboChart_basic" = "ITree_RoboChart" +
  options [timeout = 600, document = pdf, document_output = "output"]
  sessions
    "ITree_RoboChart"
    "ITree_Simulation"
  theories
    RoboChart_basic 
  document_files
    "root.tex"
    "images/system.pdf"
    "images/system.png"

session "RoboChart_ChemicalDetector_autonomous" in "RoboChart/examples/RoboChart_ChemicalDetector_autonomous" = "ITree_RoboChart" +
  options [timeout = 600, document = pdf, document_output = "output"]
  sessions
    "ITree_RoboChart"
  theories
    RoboChart_ChemicalDetector_autonomous 
  document_files
    "root.tex"
    "images/Module.pdf"
    "images/Chemical.pdf"
    "images/Location.pdf"
    "images/MainController.pdf"
    "images/MicroController.pdf"
    "images/GasAnalysis.pdf"
    "images/Movement.pdf"
