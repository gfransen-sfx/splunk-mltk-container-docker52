import os
import nbformat
from nbconvert import HTMLExporter
from nbconvert.preprocessors import ExecutePreprocessor

def execute_notebook(notebook_path):
    """Executes a notebook and returns the output."""
    try:
        print(f"Opening notebook {notebook_path}")
        with open(notebook_path) as f:
            nb = nbformat.read(f, as_version=4)
        
        ep = ExecutePreprocessor(timeout=600, kernel_name='python3')
        
        # Setting the working directory to the notebook's directory
        exec_dir = os.path.dirname(notebook_path)
        print(f"Executing notebook with execution path: {exec_dir}")
        ep.preprocess(nb, {'metadata': {'path': exec_dir}})
        
        # Check for soft fail condition
        output_text = nbformat.writes(nb)
        if "One or more tests failed due to" in output_text:
            return "soft_fail", nb
        
        return "pass", nb
    
    except Exception as e:
        print(f"An error occurred: {e}")
        return "fail", nb  # Return the notebook even if it fails

def convert_notebook_to_html(notebook_node):
    """Converts a notebook node to HTML."""
    html_exporter = HTMLExporter()
    (body, resources) = html_exporter.from_notebook_node(notebook_node)
    return body

def generate_summary(total_notebooks, passed, failed, soft_fails):
    """Generates a summary of the test results with larger text."""
    summary_html = f"""
    <h1 style="font-size: 120%;">Test Summary</h1>
    <p style="font-size: 120%;"><strong>Total Notebooks:</strong> {total_notebooks}</p>
    <p style="font-size: 120%;"><strong>Passed:</strong> {passed}</p>
    <p style="font-size: 120%;"><strong>Failed:</strong> {failed}</p>
    <p style="font-size: 120%;"><strong>Soft Fails:</strong> {soft_fails}</p>
    <hr style="margin: 20px 0;"/>
    """
    return summary_html

def main(notebooks_dir, output_file):
    """Finds all notebooks in a directory, executes them, and writes the results to a single file."""
    notebook_files = [f for f in os.listdir(notebooks_dir) if f.endswith('.ipynb')]
    
    total_notebooks = len(notebook_files)
    passed = 0
    failed = 0
    soft_fails = 0
    notebook_results = []
    failed_results = []
    soft_failed_results = []
    passed_results = []

    # Execute all notebooks and collect results
    for notebook_file in notebook_files:
        notebook_path = os.path.join(notebooks_dir, notebook_file)
        print(f"Executing {notebook_file}...")
        
        result, executed_nb = execute_notebook(notebook_path)
        
        if result == "pass":
            print(f"Notebook {notebook_file} executed successfully.")
            html_output = convert_notebook_to_html(executed_nb)
            passed_results.append((notebook_file, html_output))
            passed += 1
        elif result == "soft_fail":
            print(f"Notebook {notebook_file} encountered a soft fail.")
            html_output = convert_notebook_to_html(executed_nb)
            soft_failed_results.append((notebook_file, html_output))
            soft_fails += 1
        else:
            print(f"Notebook {notebook_file} encountered an issue.")
            html_output = convert_notebook_to_html(executed_nb)
            failed_results.append((notebook_file, html_output))
            failed += 1

    # Write results to the output file
    with open(output_file, 'w') as output:
        # Generate and write the summary at the top
        summary_html = generate_summary(total_notebooks, passed, failed, soft_fails)
        output.write(summary_html)

        # Separate each section with a line and increase text size
        output.write('<hr/><details>\n<summary style="font-size: 120%;">Failed Notebooks</summary>\n')
        for notebook_file, html_output in failed_results:
            output.write(f'<details>\n<summary style="font-size: 120%;">{notebook_file}</summary>\n')
            output.write(html_output)
            output.write("</details>\n<hr/>\n")
        output.write('</details>\n<hr/>')

        output.write('<hr/><details>\n<summary style="font-size: 120%;">Soft Failed Notebooks</summary>\n')
        for notebook_file, html_output in soft_failed_results:
            output.write(f'<details>\n<summary style="font-size: 120%;">{notebook_file}</summary>\n')
            output.write(html_output)
            output.write("</details>\n<hr/>\n")
        output.write('</details>\n<hr/>')

        output.write('<hr/><details>\n<summary style="font-size: 120%;">Passed Notebooks</summary>\n')
        for notebook_file, html_output in passed_results:
            output.write(f'<details>\n<summary style="font-size: 120%;">{notebook_file}</summary>\n')
            output.write(html_output)
            output.write("</details>\n<hr/>\n")
        output.write('</details>\n<hr/>')

    print(f"All notebooks have been processed. Results saved to {output_file}")

if __name__ == "__main__":
    main('./golden-cpu-ubi/', 'ubi-golden-test-results.html')
