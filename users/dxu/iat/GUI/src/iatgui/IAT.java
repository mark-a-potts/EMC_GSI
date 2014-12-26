package iatgui;

import java.io.*;
import java.awt.*;
import java.awt.event.*;

import javax.swing.*;
import javax.swing.event.*;
import javax.swing.filechooser.*;
import javax.swing.border.*;

import java.beans.*;
import java.util.Random;
import java.util.Vector;
import java.util.Map;
import java.util.HashMap;
import java.util.Set;
import java.util.Iterator;
import java.util.LinkedList;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Enumeration;
import java.text.NumberFormat;
import java.net.*;

public class IAT extends JPanel implements SizeDefinition, ActionListener,
		ItemListener, PropertyChangeListener {

	// 1. Main panels
	private JPanel theTitlePanel = new JPanel();
	private JPanel theRunPanel = new JPanel();
	private JPanel theConfigPanel = new JPanel();

	SpringLayout theConfigPanelLayout = new SpringLayout();

	// 2. Components of theRunPanel
	private JPanel theIatCboxPanel = new JPanel(new GridLayout(5, 1));
	private JButton theRunBtn = new JButton("Run");
	private JButton theStatBtn = new JButton("Check job status");
	private JButton theParBtn = new JButton("Generate PAR");

	// 3. Components of theConfigPanel

	/*
	 * 4. Configuration for individual IAT config panels
	 */
	// 0) Default Empty config panel
//	private JTextArea theEmptyTxt = new JTextArea("");

	// 5. IAT choice and its components
	private Choice theIAT_Choice = new Choice();
	private Choice theVsdb_Choice = new Choice();

	private JCheckBox theFcstDiffCbox = new JCheckBox("Fcst Diff (FcstDiff)",
			false);
	private JCheckBox theGeCbox = new JCheckBox("Grib Extremes (Ge)", false);
	private JCheckBox theHitCbox = new JCheckBox(
			"Hurricane Intensity and Track (Hit)", false);
	private JCheckBox theRadmonCbox = new JCheckBox("Radmon", false);
	private JCheckBox theVsdbCbox = new JCheckBox("Vsdb", false);

	// 6. Five package classes
	private JobStat theJobStat = new JobStat();
	private EmptyConfig theEmptyConfig = new EmptyConfig();

	private FcstDiff theFcstDiff = new FcstDiff();
	private Ge theGe = new Ge();
	private Hit theHit = new Hit();
	private Radmon theRadmon = new Radmon();
	private Vsdb theVsdb = new Vsdb();

	// Constructor
	public IAT() {
		// Set up initial panel
		setInitialPanel();

		// Add listener
		theIAT_Choice.addItemListener(this);
		theVsdb_Choice.addItemListener(this);

		theRunBtn.addActionListener(this);
		theStatBtn.addActionListener(this);

	}

	/**
	 * Invoked when button clicked
	 */
	public void actionPerformed(ActionEvent evt) {

		// Job stat button is clicked
		if (evt.getSource() == theStatBtn) {
			System.out.println("stat btn clicked");
			JOptionPane.showMessageDialog(null, "stat is clicked");
			
			// Run "ps -u $LOGNAME " to  
			if (DirSetter.isLinux()) {
				String aStr = null;
				try {
					// run "showJobStat.sh"			
					Process prcs = Runtime.getRuntime().exec(DirSetter.getGUI_Root() + "/showJobStat.sh" );

					JTextArea aTxt = new JTextArea("");
					// stdout
					BufferedReader stdout = new BufferedReader(
							new InputStreamReader(prcs.getInputStream()));
					// stderr
					BufferedReader stderr = new BufferedReader(
							new InputStreamReader(prcs.getErrorStream()));

					// read the output from the command
					System.out
							.println("Here is the standard output of the command:\n");
					while ((aStr = stdout.readLine()) != null) {
						System.out.println(aStr);
						aTxt.append(aStr + "\n");
					}

					// read any errors from the attempted command
					System.out
							.println("Here is the standard error of the command (if any):\n");
					while ((aStr = stderr.readLine()) != null) {
						System.out.println(aStr);
						aTxt.append(aStr + "\n");
					}
					
					theJobStat.setJobStat(aTxt.getText());
					
					addJobStatPanel();
					

				} catch (IOException e) {
					JOptionPane.showMessageDialog(null, "exception thrown");
					System.out
							.println("exception happened - here's what I know: ");
					e.printStackTrace();
					System.exit(-1);
				}
			}

			addJobStatPanel();
		}

		// Run button is clicked
		if (evt.getSource() == theRunBtn) {
			System.out.println("run btn clicked");
			JOptionPane.showMessageDialog(null, "run is clicked");

			if (theFcstDiffCbox.isSelected()) {
				System.out.println("fcstDiff is selected");
			}

			if (theGeCbox.isSelected()) {
				System.out.println("ge is selected");
			}

			if (theHitCbox.isSelected()) {
				System.out.println("hit is selected");
			}

			if (theRadmonCbox.isSelected()) {

				System.out.println("radmon is selected");
			}

			if (theVsdbCbox.isSelected()) {
				System.out.println("vsdb is selected.");
			}

		}
	}

	/**
	 * Action to take when item chosen
	 */
	public void itemStateChanged(ItemEvent e) {

		Object source = e.getItemSelectable();

		if (source == theIAT_Choice) {
			switch (theIAT_Choice.getSelectedItem()) {
			case "choose...":
				addEmptyConfigPanel();
				break;
			case "FcstDiff":
				addFcstDiffConfigPanel();
				break;
			case "Ge":
				addGE_ConfigPanel();
				break;
			case "hit":
				addHIT_ConfigPanel();
				break;
			case "Radmon":
				addRADMON_ConfigPanel();
				break;
			case "Vsdb":
				addVSDB_ConfigPanel();
				break;
			default:
				addEmptyConfigPanel();
				break;
			}
		} else if (source == theVsdb_Choice) {
			switch (theVsdb_Choice.getSelectedItem()) {
			case "top-level config":
				addVsdbTopLevelConfigPanel();
				break;
			case "step 1 config":
				addVsdbstep_1_ConfigPanel();
				break;
			case "step 2 config":
				addVsdbstep_2_ConfigPanel();
				break;
			case "step 3 config":
				addVsdbstep_3_ConfigPanel();
				break;
			case "step 4 config":
				addVsdbstep_4_ConfigPanel();
				break;
			case "step 5 config":
				addVsdbstep_5_ConfigPanel();
				break;
			case "step 6 config":
				addVsdbstep_6_ConfigPanel();
				break;
			default:
				addVsdbTopLevelConfigPanel();
				break;
			}
		}

	}

	private void addJobStatPanel() {
		// ======================================
		// Step 1: Set up theConfigPanel
		// ======================================
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theFcstDiffConfigPanel into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theJobStat.theJobStatPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theJobStat within the config panel
		SpringLayout.Constraints jobStatlCons = theConfigPanelLayout
				.getConstraints(theJobStat.theJobStatPanel);
		jobStatlCons.setX(Spring.constant(10));
		jobStatlCons.setY(Spring.constant(35));
		jobStatlCons.setWidth(Spring.constant(PANEL_WIDTH));
		jobStatlCons.setHeight(Spring.constant(PANEL_HEIGHT));

		theJobStat.showConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();
	}

	private void addEmptyConfigPanel() {
		// ======================================
		// Step 1: Set up theConfigPanel
		// ======================================
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theFcstDiffConfigPanel into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theEmptyConfig.theEmptyConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theFcstDiffConfigPanel within the config panel
		SpringLayout.Constraints emptyConfigPanelCons = theConfigPanelLayout
				.getConstraints(theEmptyConfig.theEmptyConfigPanel);
		emptyConfigPanelCons.setX(Spring.constant(10));
		emptyConfigPanelCons.setY(Spring.constant(35));
		emptyConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		emptyConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		theEmptyConfig.showConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();
	}

	private void addFcstDiffConfigPanel() {
		// ======================================
		// Step 1: Set up theConfigPanel
		// ======================================
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theFcstDiffConfigPanel into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theFcstDiff.theFcstDiffConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theFcstDiffConfigPanel within the config panel
		SpringLayout.Constraints fcstDiffConfigPanelCons = theConfigPanelLayout
				.getConstraints(theFcstDiff.theFcstDiffConfigPanel);
		fcstDiffConfigPanelCons.setX(Spring.constant(10));
		fcstDiffConfigPanelCons.setY(Spring.constant(35));
		fcstDiffConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		fcstDiffConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		theFcstDiff.showConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();
	}

	private void addGE_ConfigPanel() {

	}

	private void addHIT_ConfigPanel() {

	}

	private void addVSDB_ConfigPanel() {
		theConfigPanel.removeAll();

		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theFcstDiffConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addRADMON_ConfigPanel() {
	}

	private void addVsdbTopLevelConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theTopLevelConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdb_Choice within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdb_Choice within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theTopLevelConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showTopLevelConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addVsdbstep_1_ConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theStep1ConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdbStep1ConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdbStep1ConfigPanel within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theStep1ConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showStep1ConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addVsdbstep_2_ConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theStep2ConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdbStep2ConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdbStep2ConfigPanel within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theStep2ConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showStep2ConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addVsdbstep_3_ConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theStep3ConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdbStep3ConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdbStep3ConfigPanel within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theStep3ConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showStep3ConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addVsdbstep_4_ConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theStep4ConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdbStep4ConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdbStep4ConfigPanel within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theStep4ConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showStep4ConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addVsdbstep_5_ConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theStep5ConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdbStep5ConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdbStep5ConfigPanel within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theStep5ConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showStep5ConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();

	}

	private void addVsdbstep_6_ConfigPanel() {
		// Wipe out stuff within theConfigPanel
		theConfigPanel.removeAll();

		// Add theIAT_Choice and theVsdb_Choice into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theVsdb_Choice);
		theConfigPanel.add(theVsdb.theStep6ConfigPanel);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(150));
		iatChoiceCons.setHeight(Spring.constant(30));

		// Position theVsdbStep6ConfigPanel within the config panel
		SpringLayout.Constraints vsdbChoicelCons = theConfigPanelLayout
				.getConstraints(theVsdb_Choice);
		vsdbChoicelCons.setX(Spring.constant(180));
		vsdbChoicelCons.setY(Spring.constant(10));
		vsdbChoicelCons.setWidth(Spring.constant(150));
		vsdbChoicelCons.setHeight(Spring.constant(30));

		// Position theVsdbStep6ConfigPanel within the config panel
		SpringLayout.Constraints vsdbTopLevelConfigPanelCons = theConfigPanelLayout
				.getConstraints(theVsdb.theStep6ConfigPanel);
		vsdbTopLevelConfigPanelCons.setX(Spring.constant(10));
		vsdbTopLevelConfigPanelCons.setY(Spring.constant(35));
		vsdbTopLevelConfigPanelCons.setWidth(Spring.constant(PANEL_WIDTH));
		vsdbTopLevelConfigPanelCons.setHeight(Spring.constant(PANEL_HEIGHT));

		// Redirect vsdb panel display to class Vsdb.
		theVsdb.showStep6ConfigPanel();

		// Now refresh theConfigPanel
		theConfigPanel.revalidate();
		theConfigPanel.repaint();
	}

	/*
	 * Set up the beginning paGE_ of IAT
	 */
	private void setInitialPanel() {
		// ==================================================================
		// 1. main panel
		// ==================================================================
		add(theTitlePanel);
		add(theRunPanel);
		add(theConfigPanel);

		SpringLayout totalLayout = new SpringLayout();
		setLayout(totalLayout);

		int xPos = 30;
		int yPos = 10;
		int ySpacer = 10;

		int titlePanelWidth = 1000;
		int titlePanelHeight = 60;
		int runPanelWidth = 1000;
		int runPanelHeight = 120;
		int configPanelWidth = 1000;
		int configPanelHeight = 800;

		SpringLayout.Constraints theTitlePanelCons = totalLayout
				.getConstraints(theTitlePanel);
		theTitlePanelCons.setX(Spring.constant(xPos));
		theTitlePanelCons.setY(Spring.constant(yPos));
		theTitlePanelCons.setWidth(Spring.constant(titlePanelWidth));
		theTitlePanelCons.setHeight(Spring.constant(titlePanelHeight));

		SpringLayout.Constraints theRunPanelCons = totalLayout
				.getConstraints(theRunPanel);
		theRunPanelCons.setX(Spring.constant(xPos));
		theRunPanelCons
				.setY(Spring.constant(yPos + titlePanelHeight + ySpacer));
		theRunPanelCons.setWidth(Spring.constant(runPanelWidth));
		theRunPanelCons.setHeight(Spring.constant(runPanelHeight));

		SpringLayout.Constraints theConfigPanelCons = totalLayout
				.getConstraints(theConfigPanel);
		theConfigPanelCons.setX(Spring.constant(xPos));
		theConfigPanelCons.setY(Spring.constant(yPos + titlePanelHeight
				+ ySpacer + runPanelHeight + ySpacer));
		theConfigPanelCons.setWidth(Spring.constant(configPanelWidth));
		theConfigPanelCons.setHeight(Spring.constant(configPanelHeight));

		// ==================================================================
		// 2. theTitlePanel ( 800 x 60 )
		// ==================================================================
		JLabel titleLabel = new JLabel("Independent Assessment Tool");
		titleLabel.setFont(new Font("Nimbus Mono L", Font.BOLD, 30));

		SpringLayout theTitlePanelLayout = new SpringLayout();
		theTitlePanel.setLayout(theTitlePanelLayout);

		SpringLayout.Constraints theTitlePanelLayoutCons = theTitlePanelLayout
				.getConstraints(titleLabel);
		theTitlePanelLayoutCons.setX(Spring.constant(200));
		theTitlePanelLayoutCons.setY(Spring.constant(0));
		theTitlePanelLayoutCons.setWidth(Spring.constant(800));
		theTitlePanelLayoutCons.setHeight(Spring.constant(60));

		theTitlePanel.add(titleLabel);
		theTitlePanel.setBackground(Color.LIGHT_GRAY);

		// ==================================================================
		// 3. theRunPanel ( 800 x 120 )
		// ==================================================================
		//
		// 3.1 theIatCboxPanel
		//
		// Add components into theIatCboxPanel
		theIatCboxPanel.add(theFcstDiffCbox);
		theIatCboxPanel.add(theGeCbox);
		theIatCboxPanel.add(theHitCbox);
		theIatCboxPanel.add(theRadmonCbox);
		theIatCboxPanel.add(theVsdbCbox);

		// Set border for theIatCboxPanel
		Border lowerBorder = BorderFactory.createLoweredBevelBorder();
		TitledBorder theIatCboxPanelBorder = BorderFactory.createTitledBorder(
				lowerBorder, "IAT Selection");
		theIatCboxPanelBorder.setTitleJustification(TitledBorder.CENTER);
		theIatCboxPanel.setBorder(theIatCboxPanelBorder);

		// 3.2 Add 3 components into theRunPanel
		theRunPanel.add(theIatCboxPanel);
		theRunPanel.add(theRunBtn);
		theRunPanel.add(theStatBtn);
		theRunPanel.add(theParBtn);

		// 3.3 Position 3 components within theRunPanel
		SpringLayout theRunPanelLayout = new SpringLayout();
		theRunPanel.setLayout(theRunPanelLayout);

		int spacer = 5;
		int box1_width = 300;
		int box1_height = 100;
		int box1_x = 0;
		int box1_y = 0;

		int box2_width = 150;
		int box2_height = 30;
		int box2_x = box1_x + box1_width + spacer;
		int box2_y = box1_height - box2_height - box1_y;

		int box3_width = 150;
		int box3_height = 30;
		int box3_x = box2_x + box2_width + spacer;
		int box3_y = box2_y;

		int box4_width = 150;
		int box4_height = 30;
		int box4_x = box3_x + box3_width + spacer;
		int box4_y = box3_y;

		int xWidth = 150;
		int yHeight = 30;

		SpringLayout.Constraints iatCheckBoxPanelCons = theRunPanelLayout
				.getConstraints(theIatCboxPanel);
		iatCheckBoxPanelCons.setX(Spring.constant(box1_x));
		iatCheckBoxPanelCons.setY(Spring.constant(box1_y));
		iatCheckBoxPanelCons.setWidth(Spring.constant(box1_width));
		iatCheckBoxPanelCons.setHeight(Spring.constant(box1_height));

		SpringLayout.Constraints runButtonCons = theRunPanelLayout
				.getConstraints(theRunBtn);
		runButtonCons.setX(Spring.constant(box2_x));
		runButtonCons.setY(Spring.constant(box2_y));
		runButtonCons.setWidth(Spring.constant(box2_width));
		runButtonCons.setHeight(Spring.constant(box2_height));

		SpringLayout.Constraints statButtonCons = theRunPanelLayout
				.getConstraints(theStatBtn);
		statButtonCons.setX(Spring.constant(box3_x));
		statButtonCons.setY(Spring.constant(box3_y));
		statButtonCons.setWidth(Spring.constant(box3_width));
		statButtonCons.setHeight(Spring.constant(box3_height));

		SpringLayout.Constraints parButtonCons = theRunPanelLayout
				.getConstraints(theParBtn);
		parButtonCons.setX(Spring.constant(box4_x));
		parButtonCons.setY(Spring.constant(box4_y));
		parButtonCons.setWidth(Spring.constant(box4_width));
		parButtonCons.setHeight(Spring.constant(box4_height));

		// ==================================================================
		// 4. theConfigPanel ( 800 x 600 )
		// ==================================================================
		Border lineBorder = BorderFactory.createLineBorder(Color.black);
		LineBorder theConfigPanelBorder = (LineBorder) BorderFactory
				.createLineBorder(Color.black);
		theConfigPanel.setBorder(theConfigPanelBorder);

		// theIAT_Choice (pull-down options)
		theIAT_Choice.add("choose...");
		theIAT_Choice.add("FcstDiff");
		theIAT_Choice.add("Ge");
		theIAT_Choice.add("Hit");
		theIAT_Choice.add("Radmon");
		theIAT_Choice.add("Vsdb");

		// theIAT_Choice (pull-down options)
		theVsdb_Choice.add("choose...");
		theVsdb_Choice.add("top-level config");
		theVsdb_Choice.add("step 1 config");
		theVsdb_Choice.add("step 2 config");
		theVsdb_Choice.add("step 3 config");
		theVsdb_Choice.add("step 4 config");
		theVsdb_Choice.add("step 5 config");
		theVsdb_Choice.add("step 6 config");

		// 4.1 add components into theConfigPanel
		theConfigPanel.add(theIAT_Choice);
		theConfigPanel.add(theEmptyConfig.theEmptyConfigPanel);

		// 4.2 Position components within theConfigPanel using SpringLayout and
		// Contraint.
		theConfigPanel.setLayout(theConfigPanelLayout);

		// Position theIAT_Choice within the config panel
		SpringLayout.Constraints iatChoiceCons = theConfigPanelLayout
				.getConstraints(theIAT_Choice);
		iatChoiceCons.setX(Spring.constant(10));
		iatChoiceCons.setY(Spring.constant(10));
		iatChoiceCons.setWidth(Spring.constant(xWidth));
		iatChoiceCons.setHeight(Spring.constant(yHeight));

		// Position theEmptyConfig within the config panel
		SpringLayout.Constraints emptyConfigCons = theConfigPanelLayout
				.getConstraints(theEmptyConfig.theEmptyConfigPanel);
		emptyConfigCons.setX(Spring.constant(10));
		emptyConfigCons.setY(Spring.constant(10));
		emptyConfigCons.setWidth(Spring.constant(xWidth));
		emptyConfigCons.setHeight(Spring.constant(yHeight));

		// Redirect to class EmptyConfig to show its own components.
		theEmptyConfig.showConfigPanel();
	}

	/**
	 * Action to take whe property chanGE_d.
	 */
	public void propertyChange(PropertyChangeEvent evt) {

	}

	private static void createAndShowGUI() {
		// Create and set up the window.
		JFrame frame = new JFrame("IAT Control Panel");
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

		// Create and set up the content pane.
		JComponent newContentPane = new IAT();
		newContentPane.setPreferredSize(new Dimension(1300, 1000));
		newContentPane.setOpaque(true); // content panes must be opaque
		frame.setContentPane(newContentPane);

		// Display the window.
		frame.pack();
		frame.setSize(920, 800);
		frame.setResizable(true);
		Dimension d = Toolkit.getDefaultToolkit().getScreenSize();
		if (frame.getWidth() > d.width)
			frame.setSize(d.width, frame.getHeight());
		if (frame.getHeight() > d.height)
			frame.setSize(frame.getWidth(), d.height);

		frame.setVisible(true);
		frame.setLocationRelativeTo(null);
	}

	/**
	 * Main method to run
	 */
	public static void main(String[] args) {
		// Schedule a job for the event-dispatching thread:
		// creating and showing this application's GUI.
		javax.swing.SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				createAndShowGUI();
			}
		});
	}

}
